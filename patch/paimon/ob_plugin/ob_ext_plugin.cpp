// Copyright 2024-present Alibaba Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// \file ob_ext_plugin.cpp
/// \brief Paimon implementation of OceanBase's generic external-table plugin
/// contract (ob_external_table_plugin.h). This path uses paimon-cpp C++ APIs
/// directly; it intentionally does not include or call the legacy paimon C API.

#include "paimon/ob_external_table_plugin.h"
#include "ob_ext_plugin_host.h"
#include "ob_ext_plugin_logger.h"

#include <arrow/api.h>
#include <arrow/c/bridge.h>
#include <arrow/c/helpers.h>

#include "rapidjson/document.h"
#include "rapidjson/stringbuffer.h"
#include "rapidjson/writer.h"
#include "rapidjson/writer.h"

#include "paimon/catalog/identifier.h"
#include "paimon/catalog/table.h"
#include "paimon/common/predicate/literal_converter.h"
#include "paimon/core/schema/schema_manager.h"
#include "paimon/core/schema/table_schema.h"
#include "paimon/core/snapshot.h"
#include "paimon/core/utils/branch_manager.h"
#include "paimon/core/utils/snapshot_manager.h"
#include "paimon/defs.h"
#include "paimon/memory/memory_pool.h"
#include "paimon/predicate/literal.h"
#include "paimon/predicate/predicate_builder.h"
#include "paimon/read_context.h"
#include "paimon/reader/batch_reader.h"
#include "paimon/result.h"
#include "paimon/scan_context.h"
#include "paimon/schema/schema.h"
#include "paimon/status.h"
#include "paimon/table/source/plan.h"
#include "paimon/table/source/data_split.h"
#include "paimon/table/source/split.h"
#include "paimon/table/source/table_read.h"
#include "paimon/table/source/table_scan.h"

#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <iomanip>
#include <limits>
#include <map>
#include <memory>
#include <mutex>
#include <new>
#include <optional>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

/// Worker/session scope: lives from reader_create to reader_close; written
/// only there — every other entry point sees it const.
struct ObExtTableReaderWorkerState
{
  // Used for logging in callbacks that do not receive a host argument.
  const ObExtTableHostApi *host_ = nullptr;
  std::shared_ptr<paimon::MemoryPool> pool_;
  std::shared_ptr<paimon::Executor> executor_;
  std::shared_ptr<paimon::FileSystem> file_system_;

  // Reader-lifetime constants parsed from reader_create's JSON inputs.
  std::string table_uri_;
  std::map<std::string, std::string> options_;
  std::vector<int32_t> field_ids_;   // read projection; empty -> read all columns
  int64_t schema_id_ = -1;           // pinned read schema; -1 -> latest
};

/// Scan scope: the read pipeline built from worker constants + this scan's
/// predicate. Written only by reader_open_scan / reader_close_scan.
struct ObExtTableReaderScanState
{
  std::unique_ptr<paimon::TableRead> table_read_;
};

/// Task scope: one split + its batch reader. Written only by reader_open_task
/// / reader_next_batch / reader_close_task.
struct ObExtTableReaderTaskState
{
  // Used for logging in reader_close_task (which receives no worker argument).
  const ObExtTableHostApi *host_ = nullptr;
  // Keep Split before BatchReader so reverse destruction releases BatchReader first.
  std::shared_ptr<paimon::Split> split_;
  std::unique_ptr<paimon::BatchReader> batch_reader_;

  // Diagnostics accumulated until reader_close.
  uint64_t task_open_count_ = 0;
  uint64_t task_close_count_ = 0;
};

namespace {

// OB errnos come from the shared contract header (ob_external_table_plugin.h):
// OB_EXT_* — no local re-definition, so plugin and OB cannot drift apart.
#define OB_EXT_SUCC(ret) ((ret) == OB_EXT_SUCCESS)

constexpr const char* kPaimonSchemaDir = "schema";
constexpr const char* kPaimonHmsOutputFormat =
    "org.apache.paimon.hive.mapred.PaimonOutputFormat";
constexpr const char* kCatalogFilesystem = "filesystem";
constexpr const char* kCatalogHms = "hms";

// Paimon-PRIVATE keys carried inside the opaque catalog_context object
// (load_schema's T0 record and plan_create's pinning record). The generic
// contract never sees them: OB transports catalog_context verbatim, only this
// plugin emits/parses the contents. They are deliberately NOT OB_EXT_K_*
// protocol constants — the protocol JSON must not specialize format concepts.
constexpr const char* kCatalogCtxSchemaId = "schema_id";
constexpr const char* kCatalogCtxSnapshotId = "snapshot_id";

bool str_iequals(const char* a, const char* b)
{
  if (a == nullptr || b == nullptr) {
    return false;
  }
  while (*a != '\0' && *b != '\0') {
    const char ca = (*a >= 'A' && *a <= 'Z') ? static_cast<char>(*a + ('a' - 'A')) : *a;
    const char cb = (*b >= 'A' && *b <= 'Z') ? static_cast<char>(*b + ('a' - 'A')) : *b;
    if (ca != cb) {
      return false;
    }
    ++a;
    ++b;
  }
  return *a == '\0' && *b == '\0';
}

bool dirs_contain_schema_dir(const rapidjson::Value& dirs)
{
  if (!dirs.IsArray()) {
    return false;
  }
  for (const auto& entry : dirs.GetArray()) {
    if (entry.IsString() && str_iequals(entry.GetString(), kPaimonSchemaDir)) {
      return true;
    }
  }
  return false;
}

bool recognize_filesystem_paimon(const char* table_uri, const rapidjson::Document& doc,
                                 const ObExtTableHostApi* host)
{
  if (!doc.HasMember(OB_EXT_K_CATALOG_TYPE)
      || !doc[OB_EXT_K_CATALOG_TYPE].IsString()
      || !str_iequals(doc[OB_EXT_K_CATALOG_TYPE].GetString(), kCatalogFilesystem)) {
    return false;
  }
  if (doc.HasMember(OB_EXT_K_DIRS) && dirs_contain_schema_dir(doc[OB_EXT_K_DIRS])) {
    return true;
  }
  if (host != nullptr && host->io.file_exists != nullptr && table_uri != nullptr
      && table_uri[0] != '\0') {
    std::string schema_path(table_uri);
    if (!schema_path.empty() && schema_path.back() != '/') {
      schema_path.push_back('/');
    }
    schema_path.append(kPaimonSchemaDir);
    const int32_t rc = host->io.file_exists(host->ctx, schema_path.c_str());
    if (rc == 1) {
      return true;
    }
    if (rc < 0) {
      // 0 = not found (normal during recognition); <0 = real host/storage error.
      OBEXT_LOG_WARN(host, "recognize_filesystem_paimon: file_exists('%s') failed, rc=%d",
                     schema_path.c_str(), (int)rc);
    }
  }
  return false;
}

bool recognize_hms_paimon(const rapidjson::Document& doc)
{
  if (!doc.HasMember(OB_EXT_K_CATALOG_TYPE)
      || !doc[OB_EXT_K_CATALOG_TYPE].IsString()
      || !str_iequals(doc[OB_EXT_K_CATALOG_TYPE].GetString(), kCatalogHms)) {
    return false;
  }
  if (!doc.HasMember(OB_EXT_K_OUTPUT_FORMAT) || !doc[OB_EXT_K_OUTPUT_FORMAT].IsString()) {
    return false;
  }
  return str_iequals(doc[OB_EXT_K_OUTPUT_FORMAT].GetString(), kPaimonHmsOutputFormat);
}

const char kBase64Alphabet[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

int status_to_errno(const paimon::Status& st)
{
  switch (st.code()) {
    case paimon::StatusCode::OK:
      return OB_EXT_SUCCESS;
    case paimon::StatusCode::Invalid:
    case paimon::StatusCode::IndexError:
    case paimon::StatusCode::KeyError:
    case paimon::StatusCode::TypeError:
      return OB_EXT_INVALID_ARGUMENT;
    case paimon::StatusCode::NotImplemented:
      return OB_EXT_NOT_SUPPORTED;
    case paimon::StatusCode::OutOfMemory:
      return OB_EXT_ALLOCATE_MEMORY_FAILED;
    case paimon::StatusCode::NotExist:
      // Missing file/dir (e.g. table location gone) is NOT an IO error — let OB
      // distinguish "path does not exist" from a real storage failure.
      return OB_EXT_FILE_NOT_EXIST;
    case paimon::StatusCode::SerializationError:
      // paimon uses one code for both directions; this plugin is read-only, so
      // every occurrence is a deserialize failure (split payload, metadata).
      return OB_EXT_DESERIALIZE_ERROR;
    case paimon::StatusCode::IOError:
      return OB_EXT_IO_ERROR;
    default:
      return OB_EXT_ERR_UNEXPECTED;
  }
}

// Log a paimon::Status failure at the CALL SITE and return the mapped OB errno.
// This MUST be a macro (not a function) so OBEXT_LOG_WARN captures the real
// __FILE__/__LINE__/__func__ of the failing paimon call — a function helper
// would uniform-locate every error at itself, hiding which call failed.
// No error object crosses the boundary.
#define OBEXT_FAIL_STATUS(st, host, where)                                          \
  (OBEXT_LOG_WARN((host), "%s: %s",                                                 \
                  (where) != nullptr ? (where) : "paimon plugin",                   \
                  (st).ToString().c_str()),                                         \
   status_to_errno(st))

// Log a C++ exception thrown out of a plugin entry point. Takes the caller's
// source location explicitly (a function cannot capture __FILE__/__LINE__ at
// its call site), so the log points at the catch block, not at this helper.
// Invoke via the OBEXT_FAIL_EXCEPTION macro.
int fail_exception_at(const ObExtTableHostApi* host, const char* where,
                      const char* file, int32_t line, const char* func)
{
  const char* w = (where != nullptr) ? where : "paimon plugin";
  int ret = OB_EXT_ERR_UNEXPECTED;
  try {
    throw;
  } catch (const paimon::Status& st) {
    OBEXT_LOG_WARN_AT(host, file, line, func, "%s: %s", w, st.ToString().c_str());
    ret = status_to_errno(st);
  } catch (const std::exception& e) {
    OBEXT_LOG_WARN_AT(host, file, line, func, "%s: std exception: %s", w, e.what());
  } catch (...) {
    OBEXT_LOG_WARN_AT(host, file, line, func, "%s: unknown C++ exception", w);
  }
  return ret;
}
#define OBEXT_FAIL_EXCEPTION(host, where) \
  fail_exception_at((host), (where), __FILE__, __LINE__, __func__)

bool is_empty_json(const char* json)
{
  return json == nullptr || json[0] == '\0';
}

std::string json_value_to_string(const rapidjson::Value& v)
{
  if (v.IsString()) {
    return std::string(v.GetString(), v.GetStringLength());
  } else if (v.IsBool()) {
    return v.GetBool() ? "true" : "false";
  } else if (v.IsInt64()) {
    return std::to_string(v.GetInt64());
  } else if (v.IsUint64()) {
    return std::to_string(v.GetUint64());
  } else if (v.IsDouble()) {
    std::ostringstream oss;
    // max_digits10: round-trip doubles exactly through the options JSON
    // (the default ostringstream precision of 6 is lossy).
    oss << std::setprecision(std::numeric_limits<double>::max_digits10) << v.GetDouble();
    return oss.str();
  } else {
    rapidjson::StringBuffer sb;
    rapidjson::Writer<rapidjson::StringBuffer> writer(sb);
    v.Accept(writer);
    return std::string(sb.GetString(), sb.GetSize());
  }
}

int parse_options_json(const char* options_json, std::map<std::string, std::string>& options,
                       const ObExtTableHostApi* host)
{
  int ret = OB_EXT_SUCCESS;
  options.clear();
  if (!is_empty_json(options_json)) {
    rapidjson::Document doc;
    doc.Parse(options_json);
    if (doc.HasParseError() || !doc.IsObject()) {
      OBEXT_LOG_WARN(host, "parse_options_json: options_json must be a JSON object");
      ret = OB_EXT_INVALID_ARGUMENT;
    } else {
      for (auto it = doc.MemberBegin(); OB_EXT_SUCC(ret) && it != doc.MemberEnd(); ++it) {
        if (!it->name.IsString()) {
          OBEXT_LOG_WARN(host, "parse_options_json: option key must be a string");
          ret = OB_EXT_INVALID_ARGUMENT;
        } else {
          const std::string key(it->name.GetString(), it->name.GetStringLength());
          if (key == "location" || key == "access_info" || key == OB_EXT_K_CATALOG_CONTEXT) {
            // OB structural / catalog-context fields; not scan options — skip.
          } else if (key == OB_EXT_K_EXT_OPTIONS) {
            // Opaque per-query tuning blob: unwrap the nested object and merge
            // each member into the flat options map. Only structure is
            // validated here; value legality is paimon CoreOptions' job.
            if (!it->value.IsObject()) {
              OBEXT_LOG_WARN(host, "parse_options_json: ext_options must be a JSON object");
              ret = OB_EXT_INVALID_ARGUMENT;
            } else {
              for (auto inner = it->value.MemberBegin();
                   OB_EXT_SUCC(ret) && inner != it->value.MemberEnd(); ++inner) {
                if (!inner->name.IsString()) {
                  OBEXT_LOG_WARN(host, "parse_options_json: ext_options member key must be a string");
                  ret = OB_EXT_INVALID_ARGUMENT;
                } else {
                  const std::string ikey(inner->name.GetString(), inner->name.GetStringLength());
                  options[ikey] = json_value_to_string(inner->value);
                }
              }
            }
          } else {
            options[key] = json_value_to_string(it->value);
          }
        }
      }
    }
  }
  return ret;
}

int parse_field_ids_projection(const char* projection_json, std::vector<int32_t>& field_ids,
                               const ObExtTableHostApi* host)
{
  field_ids.clear();
  if (is_empty_json(projection_json)) {
    return OB_EXT_SUCCESS;
  }
  rapidjson::Document doc;
  doc.Parse(projection_json);
  if (doc.HasParseError() || !doc.IsObject()) {
    OBEXT_LOG_WARN(host, "parse_field_ids_projection: read_projection_json must be a JSON object");
    return OB_EXT_INVALID_ARGUMENT;
  }
  auto it = doc.FindMember(OB_EXT_K_FIELD_IDS);
  if (it == doc.MemberEnd() || it->value.IsNull()) {
    return OB_EXT_SUCCESS;
  }
  if (!it->value.IsArray()) {
    OBEXT_LOG_WARN(host, "parse_field_ids_projection: read_projection_json.field_ids must be an array");
    return OB_EXT_INVALID_ARGUMENT;
  }
  for (const auto& v : it->value.GetArray()) {
    if (!v.IsInt()) {
      OBEXT_LOG_WARN(host, "parse_field_ids_projection: read_projection_json.field_ids contains non-int value");
      return OB_EXT_INVALID_ARGUMENT;
    }
    field_ids.push_back(v.GetInt());
  }
  return OB_EXT_SUCCESS;
}

// Copy a JSON payload into a host-allocated output buffer. The buffer is
// ALWAYS allocated len+1 (payload + NUL); the paired destroy callbacks know
// this and free len+1, so alloc/free sizes stay consistent even for a
// size-aware host allocator. `out_len` reports the PAYLOAD length (no NUL).
int copy_string_to_host(const ObExtTableHostApi* host, const char* data, size_t len,
                        char** out, int32_t* out_len)
{
  if (host == nullptr || host->mem.mem_alloc == nullptr || out == nullptr || out_len == nullptr) {
    OBEXT_LOG_WARN(host, "copy_string_to_host: invalid output buffer argument");
    return OB_EXT_INVALID_ARGUMENT;
  }
  // len+1 must not overflow int32_t: reject len == INT32_MAX as well.
  if (len > static_cast<size_t>(std::numeric_limits<int32_t>::max()) - 1) {
    OBEXT_LOG_WARN(host, "copy_string_to_host: output JSON is too large, size=%zu", len);
    return OB_EXT_INVALID_ARGUMENT;
  }
  const int32_t n = static_cast<int32_t>(len);
  char* buf = static_cast<char*>(host->mem.mem_alloc(host->ctx, n + 1, /*alignment*/ 0));
  if (buf == nullptr) {
    OBEXT_LOG_WARN(host, "copy_string_to_host: host mem_alloc failed, size=%d", n + 1);
    return OB_EXT_ALLOCATE_MEMORY_FAILED;
  }
  if (n > 0) {
    std::memcpy(buf, data, n);
  }
  buf[n] = '\0';
  *out = buf;
  *out_len = n;
  return OB_EXT_SUCCESS;
}

int copy_string_to_host(const ObExtTableHostApi* host, const std::string& s,
                        char** out, int32_t* out_len)
{
  return copy_string_to_host(host, s.data(), s.size(), out, out_len);
}

std::string base64_encode(const char* data, int32_t len)
{
  std::string out;
  if (data == nullptr || len <= 0) {
    return out;
  }
  out.reserve(((static_cast<size_t>(len) + 2) / 3) * 4);
  const unsigned char* p = reinterpret_cast<const unsigned char*>(data);
  for (int32_t i = 0; i < len; i += 3) {
    const uint32_t b0 = p[i];
    const uint32_t b1 = (i + 1 < len) ? p[i + 1] : 0;
    const uint32_t b2 = (i + 2 < len) ? p[i + 2] : 0;
    const uint32_t triple = (b0 << 16) | (b1 << 8) | b2;
    out.push_back(kBase64Alphabet[(triple >> 18) & 0x3f]);
    out.push_back(kBase64Alphabet[(triple >> 12) & 0x3f]);
    out.push_back((i + 1 < len) ? kBase64Alphabet[(triple >> 6) & 0x3f] : '=');
    out.push_back((i + 2 < len) ? kBase64Alphabet[triple & 0x3f] : '=');
  }
  return out;
}

int base64_value(unsigned char c)
{
  if (c >= 'A' && c <= 'Z') return c - 'A';
  if (c >= 'a' && c <= 'z') return c - 'a' + 26;
  if (c >= '0' && c <= '9') return c - '0' + 52;
  if (c == '+') return 62;
  if (c == '/') return 63;
  return -1;
}

bool base64_decode(const char* data, size_t len, std::string& out)
{
  out.clear();
  if (data == nullptr) {
    return false;
  }
  int val = 0;
  int bits = -8;
  for (size_t i = 0; i < len; ++i) {
    const unsigned char c = static_cast<unsigned char>(data[i]);
    if (c == '=') {
      break;
    }
    const int d = base64_value(c);
    if (d < 0) {
      return false;
    }
    val = (val << 6) + d;
    bits += 6;
    if (bits >= 0) {
      out.push_back(static_cast<char>((val >> bits) & 0xff));
      bits -= 8;
    }
  }
  return true;
}

int get_task_string(const rapidjson::Document& doc, const char* key, std::string& out,
                    const ObExtTableHostApi* host)
{
  int ret = OB_EXT_SUCCESS;
  auto it = doc.FindMember(key);
  if (it == doc.MemberEnd() || !it->value.IsString()) {
    OBEXT_LOG_WARN(host, "get_task_string: task_json misses required string field: %s",
                   key != nullptr ? key : "(null)");
    ret = OB_EXT_INVALID_ARGUMENT;
  } else {
    out.assign(it->value.GetString(), it->value.GetStringLength());
  }
  return ret;
}

// Extract the pinned read schema id from options_json's catalog_context
// (plugin-private blob embedded by OB). Absent => -1 (use the latest schema).
int extract_options_schema_id(const char* options_json, int64_t& schema_id,
                              const ObExtTableHostApi* host)
{
  int ret = OB_EXT_SUCCESS;
  schema_id = -1;
  if (!is_empty_json(options_json)) {
    rapidjson::Document doc;
    doc.Parse(options_json);
    if (doc.HasParseError() || !doc.IsObject()) {
      OBEXT_LOG_WARN(host, "reader_create: options_json must be a JSON object");
      ret = OB_EXT_INVALID_ARGUMENT;
    } else {
      const rapidjson::Value::ConstMemberIterator cit = doc.FindMember(OB_EXT_K_CATALOG_CONTEXT);
      if (cit != doc.MemberEnd() && cit->value.IsObject()) {
        const rapidjson::Value::ConstMemberIterator scit =
            cit->value.FindMember(kCatalogCtxSchemaId);
        if (scit != cit->value.MemberEnd() && scit->value.IsInt64()) {
          schema_id = scit->value.GetInt64();
        }
      }
    }
  }
  return ret;
}

// Parse the task-scope key (payload_b64 -> serialized split bytes) of a
// scan-task object. Scan-scope keys are ignored (already consumed at
// reader_create / reader_open_scan).
int parse_task_payload_json(const char* task_json, int32_t task_len, std::string& split_bytes,
                            const ObExtTableHostApi* host)
{
  int ret = OB_EXT_SUCCESS;
  if (task_json == nullptr || task_len <= 0) {
    OBEXT_LOG_WARN(host, "parse_task_payload_json: task_json is invalid, task_json=%p task_len=%d",
                   (const void*)task_json, (int)task_len);
    ret = OB_EXT_INVALID_ARGUMENT;
  } else {
    rapidjson::Document doc;
    doc.Parse(task_json, static_cast<rapidjson::SizeType>(task_len));
    if (doc.HasParseError() || !doc.IsObject()) {
      OBEXT_LOG_WARN(host, "parse_task_payload_json: task_json must be a JSON object");
      ret = OB_EXT_INVALID_ARGUMENT;
    } else {
      std::string payload_b64;
      if (OB_EXT_SUCCESS != (ret = get_task_string(doc, OB_EXT_K_PAYLOAD_B64, payload_b64, host))) {
      } else if (!base64_decode(payload_b64.data(), payload_b64.size(), split_bytes)) {
        // Undecodable plugin-serialized payload => corrupt scan-task data.
        OBEXT_LOG_WARN(host, "parse_task_payload_json: task payload_b64 is invalid");
        ret = OB_EXT_DESERIALIZE_ERROR;
      }
    }
  }
  return ret;
}

// =============================================================================
// Paimon-native schema JSON  ->  OB contract schema JSON.
//
// The source of truth is paimon's own GetJsonSchema() (FieldType-based, no arrow
// round-trip — arrow would already have lost type info, e.g. TIMESTAMP precision,
// the BYTES/BLOB aliases, NOT NULL on the type string). This translator maps
// paimon's type vocabulary + structure onto the neutral contract shape:
//   paimon field  {id, name, type}                  -> contract column {field_id, name, ext_type, ...}
//   paimon primitive "INT" / "INT NOT NULL"         -> ext_type + nullable
//   paimon "DECIMAL(p, s)"                          -> ext_type DECIMAL + precision/scale
//   paimon "TIMESTAMP(p)"                           -> ext_type DATETIME + precision (tz-agnostic)
//   paimon "TIMESTAMP(p) WITH LOCAL TIME ZONE"      -> ext_type TIMESTAMP + precision (instant)
//   paimon "BYTES"/"BLOB"                           -> ext_type BINARY
//   paimon ARRAY {"type":"ARRAY","element":<type>}  -> ext_type ARRAY + children:[<element column>]
//   paimon MAP {"type":"MAP","key":<t>,"value":<t>} -> ext_type MAP + children:[<key column>, <value column>]
//   paimon ROW                                      -> ext_type UNKNOWN (OB_NOT_SUPPORTED)
// Nullability: paimon encodes it as a " NOT NULL" suffix on the type string —
// on primitives AND on complex-type objects (ArrayType::ToJson emits
// "ARRAY NOT NULL"); both go through the same strip_not_null() rule. Field
// names use the shared OB_EXT_K_* constants (single source of truth with OB).
// =============================================================================

namespace {

// Map a paimon primitive base-type string (NOT NULL already stripped) to the
// contract ext_type NAME string. Parses DECIMAL(p,s) / TIMESTAMP(p) for accuracy.
// Returns nullptr for unrecognized types (caller emits UNKNOWN).
const char* paimon_prim_to_ext(const std::string& s, int32_t& precision, int32_t& scale)
{
  precision = -1;
  scale = -1;
  if (s == "BOOLEAN") return "BOOL";
  if (s == "TINYINT") return "TINYINT";
  if (s == "SMALLINT") return "SMALLINT";
  if (s == "INT") return "INT";
  if (s == "BIGINT") return "BIGINT";
  if (s == "FLOAT") return "FLOAT";
  if (s == "DOUBLE") return "DOUBLE";
  if (s == "STRING") return "STRING";
  if (s == "BYTES" || s == "BLOB") return "BINARY";
  if (s == "DATE") return "DATE";
  if (s.rfind("DECIMAL(", 0) == 0) {
    // "DECIMAL(23, 5)" — parse precision/scale (no cstdio: use std::stoi).
    const size_t lp = s.find('(');
    const size_t cm = s.find(',', lp == std::string::npos ? 0 : lp);
    const size_t rp = s.find(')', cm == std::string::npos ? 0 : cm);
    if (lp != std::string::npos && cm != std::string::npos && rp != std::string::npos) {
      try {
        int p = std::stoi(s.substr(lp + 1, cm - lp - 1));
        int sc = std::stoi(s.substr(cm + 1, rp - cm - 1));
        precision = p; scale = sc; return "DECIMAL";
      } catch (...) { return nullptr; }
    }
    return nullptr;
  }
  // TIMESTAMP family. paimon emits "TIMESTAMP(p)" (timezone-agnostic wall
  // clock) and "TIMESTAMP(p) WITH LOCAL TIME ZONE" (an instant). Map the
  // former to contract DATETIME and the latter to TIMESTAMP (OB MySQL mode:
  // DATETIME is tz-agnostic, TIMESTAMP is a session-tz instant), and carry the
  // sub-second precision through (OB applies it as fsp, clamped to its max).
  {
    const std::string ltz_suffix = " WITH LOCAL TIME ZONE";
    bool is_ltz = false;
    std::string base = s;
    if (s.size() >= ltz_suffix.size()
        && s.compare(s.size() - ltz_suffix.size(), ltz_suffix.size(), ltz_suffix) == 0) {
      is_ltz = true;
      base = s.substr(0, s.size() - ltz_suffix.size());
    }
    if (base == "TIMESTAMP") {
      return is_ltz ? "TIMESTAMP" : "DATETIME";
    }
    if (base.rfind("TIMESTAMP(", 0) == 0) {
      // "TIMESTAMP(9)" — parse the precision into the contract precision field.
      const size_t lp = base.find('(');
      const size_t rp = base.find(')', lp == std::string::npos ? 0 : lp);
      if (lp != std::string::npos && rp != std::string::npos) {
        try {
          precision = std::stoi(base.substr(lp + 1, rp - lp - 1));
          return is_ltz ? "TIMESTAMP" : "DATETIME";
        } catch (...) { return nullptr; }
      }
      return nullptr;
    }
  }
  return nullptr;
}

// Strip a trailing " NOT NULL" from a paimon primitive type string; returns
// nullability (false if the suffix was present).
bool strip_not_null(std::string& s)
{
  const std::string suffix = " NOT NULL";
  if (s.size() >= suffix.size() && s.compare(s.size() - suffix.size(), suffix.size(), suffix) == 0) {
    s.erase(s.size() - suffix.size());
    return false;
  }
  return true;
}

// Build one contract column object from a paimon field's (id, name, type).
// `ptype` is the paimon "type" value: a string (primitive) or an object
// (ARRAY/MAP/ROW). For ARRAY, the element becomes children[0]; for MAP, key and
// value become children[0]/children[1] (recursive, same shape) — OB recurses to
// build "ARRAY(<element>)" / "MAP(<key>, <value>)".
rapidjson::Value build_column_from_paimon(int32_t field_id, const std::string& name,
                                          const rapidjson::Value& ptype,
                                          rapidjson::Document::AllocatorType& al)
{
  rapidjson::Value c(rapidjson::kObjectType);
  c.AddMember(rapidjson::StringRef(OB_EXT_K_FIELD_ID), field_id, al);
  c.AddMember(rapidjson::StringRef(OB_EXT_K_NAME),
              rapidjson::Value(name.c_str(),
                               static_cast<rapidjson::SizeType>(name.size()), al),
              al);

  const char* ext = "UNKNOWN";
  int32_t precision = -1;
  int32_t scale = -1;
  bool nullable = true;

  if (ptype.IsString()) {
    std::string s(ptype.GetString(), ptype.GetStringLength());
    nullable = strip_not_null(s);
    const char* m = paimon_prim_to_ext(s, precision, scale);
    if (m != nullptr) { ext = m; }
    else { ext = "UNKNOWN"; }
  } else if (ptype.IsObject()) {
    std::string tstr;
    const rapidjson::Value::ConstMemberIterator tit = ptype.FindMember("type");
    if (tit != ptype.MemberEnd() && tit->value.IsString()) {
      tstr.assign(tit->value.GetString(), tit->value.GetStringLength());
    }
    // Complex-type objects carry nullability on the "type" string too:
    // ArrayType::ToJson emits WithNullable("ARRAY") -> "ARRAY NOT NULL".
    // Strip it with the same rule as primitives before comparing.
    nullable = strip_not_null(tstr);
    if (tstr == "ARRAY") {
      ext = "ARRAY";
      const rapidjson::Value::ConstMemberIterator eit = ptype.FindMember("element");
      if (eit == ptype.MemberEnd()) {
        ext = "UNKNOWN";  // malformed ARRAY (no element)
      } else {
        rapidjson::Value children(rapidjson::kArrayType);
        children.PushBack(
            build_column_from_paimon(/*field_id=*/0, /*name=*/"element", eit->value, al), al);
        c.AddMember(rapidjson::StringRef(OB_EXT_K_CHILDREN), children.Move(), al);
      }
    } else if (tstr == "MAP") {
      const rapidjson::Value::ConstMemberIterator kit = ptype.FindMember("key");
      const rapidjson::Value::ConstMemberIterator vit = ptype.FindMember("value");
      if (kit == ptype.MemberEnd() || vit == ptype.MemberEnd()) {
        ext = "UNKNOWN";  // malformed MAP (no key/value)
      } else {
        ext = "MAP";
        // children[0] = key, children[1] = value (recursive, same shape) —
        // OB recurses to build "MAP(<key>, <value>)".
        rapidjson::Value children(rapidjson::kArrayType);
        children.PushBack(
            build_column_from_paimon(/*field_id=*/0, /*name=*/"key", kit->value, al), al);
        children.PushBack(
            build_column_from_paimon(/*field_id=*/0, /*name=*/"value", vit->value, al), al);
        c.AddMember(rapidjson::StringRef(OB_EXT_K_CHILDREN), children.Move(), al);
      }
    } else {
      ext = "UNKNOWN";  // ROW / STRUCT / others
    }
  }

  c.AddMember(rapidjson::StringRef(OB_EXT_K_EXT_TYPE), rapidjson::StringRef(ext), al);
  c.AddMember(rapidjson::StringRef(OB_EXT_K_PRECISION), precision, al);
  c.AddMember(rapidjson::StringRef(OB_EXT_K_SCALE), scale, al);
  c.AddMember(rapidjson::StringRef(OB_EXT_K_LENGTH), -1, al);
  c.AddMember(rapidjson::StringRef(OB_EXT_K_NULLABLE), nullable, al);
  return c;
}

}  // namespace

// Translate paimon's GetJsonSchema() output into the neutral contract schema JSON.
// When `snapshot_id_at_load` is set, embeds schema_id + snapshot_id inside
// catalog_context (opaque to OB; plugin reads it back from options_json).
int build_schema_json(const std::string& paimon_schema_json, std::string& out,
                      const std::optional<int64_t>& snapshot_id_at_load = std::nullopt)
{
  rapidjson::Document pdoc;
  pdoc.Parse(paimon_schema_json.c_str(), paimon_schema_json.size());
  if (pdoc.HasParseError() || !pdoc.IsObject()) {
    return OB_EXT_INVALID_ARGUMENT;
  }
  rapidjson::Document odoc;
  odoc.SetObject();
  rapidjson::Document::AllocatorType& al = odoc.GetAllocator();
  rapidjson::Value cols(rapidjson::kArrayType);

  const rapidjson::Value::ConstMemberIterator fit = pdoc.FindMember("fields");
  if (fit == pdoc.MemberEnd() || !fit->value.IsArray()) {
    return OB_EXT_INVALID_ARGUMENT;
  }
  const rapidjson::Value& fields = fit->value;
  for (rapidjson::SizeType i = 0; i < fields.Size(); ++i) {
    const rapidjson::Value& f = fields[i];
    int32_t fid = f.HasMember("id") && f["id"].IsInt() ? f["id"].GetInt() : static_cast<int32_t>(i);
    std::string name = f.HasMember("name") && f["name"].IsString() ? f["name"].GetString() : "";
    const rapidjson::Value::ConstMemberIterator tit = f.FindMember("type");
    const rapidjson::Value null_type;
    const rapidjson::Value& ptype = (tit != f.MemberEnd()) ? tit->value : null_type;
    cols.PushBack(build_column_from_paimon(fid, name, ptype, al), al);
  }
  odoc.AddMember(rapidjson::StringRef(OB_EXT_K_COLUMNS), cols, al);
  // Carry paimon's partition key names through to OB (option B: mark partition
  // columns, do NOT build OB partitions — partition pruning is delegated to the
  // plugin/SDK via partition_filter_json at plan_create). paimon's GetJsonSchema
  // emits "partitionKeys" as a JSON array of field-name strings.
  const rapidjson::Value::ConstMemberIterator pit = pdoc.FindMember("partitionKeys");
  if (pit != pdoc.MemberEnd() && pit->value.IsArray()) {
    rapidjson::Value pkeys(rapidjson::kArrayType);
    for (rapidjson::SizeType i = 0; i < pit->value.Size(); ++i) {
      const rapidjson::Value& pk = pit->value[i];
      if (pk.IsString()) {
        pkeys.PushBack(rapidjson::Value(pk.GetString(), static_cast<rapidjson::SizeType>(pk.GetStringLength()), al), al);
      }
    }
    odoc.AddMember(rapidjson::StringRef(OB_EXT_K_PARTITION_KEYS), pkeys, al);
  }
  // Plugin-private catalog context (T0): OB stores verbatim and passes back
  // inside options_json at plan_create. Format-specific keys live here only.
  rapidjson::Value catalog_ctx(rapidjson::kObjectType);
  bool has_catalog_ctx = false;
  const rapidjson::Value::ConstMemberIterator sit = pdoc.FindMember("id");
  if (sit != pdoc.MemberEnd() && sit->value.IsInt64()) {
    catalog_ctx.AddMember(rapidjson::StringRef(kCatalogCtxSchemaId), sit->value.GetInt64(), al);
    has_catalog_ctx = true;
  }
  if (snapshot_id_at_load.has_value()) {
    catalog_ctx.AddMember(rapidjson::StringRef(kCatalogCtxSnapshotId),
                           rapidjson::Value(snapshot_id_at_load.value()), al);
    has_catalog_ctx = true;
  }
  if (has_catalog_ctx) {
    odoc.AddMember(rapidjson::StringRef(OB_EXT_K_CATALOG_CONTEXT), catalog_ctx, al);
  }
  rapidjson::StringBuffer sb;
  rapidjson::Writer<rapidjson::StringBuffer> writer(sb);
  odoc.Accept(writer);
  out.assign(sb.GetString(), sb.GetSize());
  return OB_EXT_SUCCESS;
}


std::shared_ptr<paimon::MemoryPool> make_pool_or_default(const ObExtTableHostApi* host)
{
  std::shared_ptr<paimon::MemoryPool> pool = ob_ext_paimon::make_memory_pool(host);
  return pool ? pool : paimon::GetDefaultPool();
}

// ---- partition_filter flattening (predicate-tree -> SetPartitionFilter maps) ----
// paimon's SetPartitionFilter takes vector<map<string,string>>: vector=OR,
// map=AND of col_name->value (equality only). OB emits a predicate-tree of
// eq/IN/AND/OR for partition_filter (range/IS-NULL/NE stay in the residual
// predicate). This flattens that tree into the OR-of-AND-of-equality form.
// Returns false on any non-equality node (protocol surprise) so the caller
// skips SetPartitionFilter entirely (partition pruning just doesn't happen;
// the residual predicate + OB's own filtering still produce correct results).

static bool node_kind(const rapidjson::Value& node, const char*& kind)
{
  if (!node.IsObject()) { return false; }
  auto it = node.FindMember(OB_EXT_K_KIND);
  if (it == node.MemberEnd() || !it->value.IsString()) { return false; }
  kind = it->value.GetString();
  return true;
}

static bool node_str_field(const rapidjson::Value& node, const char* field_key,
                           std::string& out)
{
  if (!node.IsObject()) { return false; }
  auto it = node.FindMember(field_key);
  if (it == node.MemberEnd() || !it->value.IsString()) { return false; }
  out.assign(it->value.GetString(), it->value.GetStringLength());
  return true;
}

// children array of a node (returns null if not an array).
static const rapidjson::Value* node_children(const rapidjson::Value& node)
{
  if (!node.IsObject()) { return nullptr; }
  auto it = node.FindMember(OB_EXT_K_CHILDREN);
  if (it == node.MemberEnd() || !it->value.IsArray()) { return nullptr; }
  return &it->value;
}

static bool col_node_name(const rapidjson::Value& node, std::string& name)
{
  const char* kind = nullptr;
  return node_kind(node, kind) && kind != nullptr && std::string(kind) == "col"
         && node_str_field(node, OB_EXT_K_NAME, name);
}

static bool lit_node_value(const rapidjson::Value& node, std::string& value)
{
  const char* kind = nullptr;
  return node_kind(node, kind) && kind != nullptr && std::string(kind) == "lit"
         && node_str_field(node, OB_EXT_K_VALUE, value);
}

// Cross-product merge for AND: combine each map in `acc` with each in `add`.
// Conflicting values for the same col (unsatisfiable term) drop the combo.
static void cross_merge(std::vector<std::map<std::string, std::string>>& acc,
                        const std::vector<std::map<std::string, std::string>>& add)
{
  if (acc.empty()) { acc = add; return; }
  if (add.empty()) { return; }  // nothing to AND with -> acc unchanged
  std::vector<std::map<std::string, std::string>> next;
  next.reserve(acc.size() * add.size());
  for (const auto& a : acc) {
    for (const auto& b : add) {
      std::map<std::string, std::string> merged = a;
      bool ok = true;
      for (const auto& kv : b) {
        auto it = merged.find(kv.first);
        if (it == merged.end()) { merged[kv.first] = kv.second; }
        else if (it->second != kv.second) { ok = false; break; }
      }
      if (ok) { next.push_back(std::move(merged)); }
    }
  }
  acc.swap(next);
}

static bool flatten_partition_filter(const rapidjson::Value& node,
                                     std::vector<std::map<std::string, std::string>>& out)
{
  const char* kind = nullptr;
  if (!node_kind(node, kind) || kind == nullptr) { return false; }
  const std::string k(kind);
  if (k == "and") {
    const rapidjson::Value* children = node_children(node);
    if (children == nullptr) { return false; }
    std::vector<std::map<std::string, std::string>> acc;
    for (rapidjson::SizeType i = 0; i < children->Size(); ++i) {
      std::vector<std::map<std::string, std::string>> child_maps;
      if (!flatten_partition_filter((*children)[i], child_maps)) { return false; }
      cross_merge(acc, child_maps);
      if (acc.empty()) { break; }  // unsatisfiable: no partition matches
    }
    out.insert(out.end(), acc.begin(), acc.end());
    return true;
  }
  if (k == "or") {
    const rapidjson::Value* children = node_children(node);
    if (children == nullptr) { return false; }
    for (rapidjson::SizeType i = 0; i < children->Size(); ++i) {
      std::vector<std::map<std::string, std::string>> child_maps;
      if (!flatten_partition_filter((*children)[i], child_maps)) { return false; }
      out.insert(out.end(), child_maps.begin(), child_maps.end());
    }
    return true;
  }
  if (k == "cmp") {
    // eq only (OB guarantees no range in partition_filter); op under "op" key.
    auto opit = node.FindMember(OB_EXT_K_OP);
    if (opit == node.MemberEnd() || !opit->value.IsString()
        || std::string(opit->value.GetString()) != "eq") {
      return false;
    }
    const rapidjson::Value* children = node_children(node);
    if (children == nullptr || children->Size() != 2) { return false; }
    std::string col_name, lit_val;
    if (!col_node_name((*children)[0], col_name)) { return false; }
    if (!lit_node_value((*children)[1], lit_val)) { return false; }
    out.push_back({{col_name, lit_val}});
    return true;
  }
  if (k == "in") {
    const rapidjson::Value* children = node_children(node);
    if (children == nullptr || children->Size() < 2) { return false; }
    std::string col_name;
    if (!col_node_name((*children)[0], col_name)) { return false; }
    for (rapidjson::SizeType i = 1; i < children->Size(); ++i) {
      std::string lit_val;
      if (!lit_node_value((*children)[i], lit_val)) { return false; }
      out.push_back({{col_name, lit_val}});  // OR of eq
    }
    return true;
  }
  // not_in / is_null / is_not_null / not / lit / col at this level -> not equality.
  return false;
}

// Parse partition_filter_json into the maps for SetPartitionFilter. Returns
// false on parse error / non-equality content (caller skips SetPartitionFilter).
static bool parse_partition_filter(const char* json,
                                   std::vector<std::map<std::string, std::string>>& out,
                                   const ObExtTableHostApi* host)
{
  out.clear();
  if (json == nullptr || json[0] == '\0') { return true; }  // no filter
  rapidjson::Document doc;
  doc.Parse(json);
  if (doc.HasParseError() || !doc.IsObject()) {
    OBEXT_LOG_WARN(host, "parse_partition_filter: invalid partition_filter json");
    return false;
  }
  return flatten_partition_filter(doc, out);
}

// Convert the shared contract predicate tree into a paimon Predicate. Unsupported
// leaves are safely omitted from AND, but never from OR/NOT. OB evaluates the
// original storage filter after reading, so this conversion is an optimization
// and cannot change query correctness.
class PredicateJsonParser {
 public:
  PredicateJsonParser(const std::shared_ptr<paimon::Schema>& schema,
                      const std::vector<int32_t>& read_field_ids,
                      const ObExtTableHostApi* host)
      : schema_(schema),
        read_field_ids_(read_field_ids),
        field_names_(schema != nullptr ? schema->FieldNames() : std::vector<std::string>()),
        host_(host)
  {}

  bool Parse(const rapidjson::Value& node, std::shared_ptr<paimon::Predicate>& out)
  {
    out.reset();
    const char* kind = nullptr;
    if (!node_kind(node, kind) || kind == nullptr) {
      return false;
    }
    const std::string k(kind);
    if (k == "and" || k == "or") {
      return ParseCompound(node, k == "and", out);
    } else if (k == "not") {
      return ParseNot(node, out);
    } else if (k == "cmp") {
      return ParseComparison(node, out);
    } else if (k == "in" || k == "not_in") {
      return ParseIn(node, k == "not_in", out);
    } else if (k == "is_null" || k == "is_not_null") {
      return ParseNullCheck(node, k == "is_not_null", out);
    }
    return false;
  }

 private:
  bool ResolveColumn(const rapidjson::Value& node,
                     int32_t& field_index,
                     std::string& field_name,
                     paimon::FieldType& field_type)
  {
    field_index = -1;
    field_type = paimon::FieldType::UNKNOWN;
    const char* kind = nullptr;
    if (!node_kind(node, kind) || kind == nullptr || std::string(kind) != "col"
        || !node_str_field(node, OB_EXT_K_NAME, field_name) || schema_ == nullptr) {
      return false;
    }

    if (read_field_ids_.empty()) {
      const auto it = std::find(field_names_.begin(), field_names_.end(), field_name);
      if (it == field_names_.end()) {
        return false;
      }
      field_index = static_cast<int32_t>(std::distance(field_names_.begin(), it));
    } else {
      const auto id_it = node.FindMember(OB_EXT_K_COL_IDX);
      if (id_it == node.MemberEnd() || !id_it->value.IsInt64()) {
        return false;
      }
      const int64_t field_id = id_it->value.GetInt64();
      if (field_id < std::numeric_limits<int32_t>::min()
          || field_id > std::numeric_limits<int32_t>::max()) {
        return false;
      }
      const auto it = std::find(read_field_ids_.begin(), read_field_ids_.end(),
                                static_cast<int32_t>(field_id));
      if (it == read_field_ids_.end()) {
        // A predicate column omitted from the read projection cannot be evaluated
        // by the paimon reader. OB will evaluate it after projection instead.
        return false;
      }
      field_index = static_cast<int32_t>(std::distance(read_field_ids_.begin(), it));
    }

    auto type_ret = schema_->GetFieldType(field_name);
    if (!type_ret.ok()) {
      OBEXT_LOG_INFO(host_, "predicate pushdown: field '%s' type unavailable: %s",
                     field_name.c_str(), type_ret.status().ToString().c_str());
      return false;
    }
    field_type = std::move(type_ret).value();
    return field_type != paimon::FieldType::UNKNOWN;
  }

  bool ConvertLiteral(const rapidjson::Value& node,
                      const paimon::FieldType field_type,
                      paimon::Literal& out)
  {
    std::string value;
    if (!lit_node_value(node, value)) {
      return false;
    }
    auto lit_ret =
        paimon::LiteralConverter::ConvertLiteralsFromString(field_type, value);
    if (!lit_ret.ok()) {
      // Some paimon types (notably DECIMAL/TIMESTAMP in this SDK version)
      // have no string converter. Leave those predicates to OB.
      OBEXT_LOG_INFO(host_, "predicate pushdown: literal conversion skipped: %s",
                     lit_ret.status().ToString().c_str());
      return false;
    }
    out = std::move(lit_ret).value();
    return true;
  }

  bool ParseCompound(const rapidjson::Value& node,
                     const bool is_and,
                     std::shared_ptr<paimon::Predicate>& out)
  {
    const rapidjson::Value* children = node_children(node);
    if (children == nullptr || children->Empty()) {
      return false;
    }
    std::vector<std::shared_ptr<paimon::Predicate>> predicates;
    predicates.reserve(children->Size());
    for (rapidjson::SizeType i = 0; i < children->Size(); ++i) {
      std::shared_ptr<paimon::Predicate> child;
      if (!Parse((*children)[i], child) || child == nullptr) {
        if (!is_and) {
          return false;  // partial OR could discard matching rows
        }
      } else {
        predicates.push_back(std::move(child));
      }
    }
    if (predicates.empty()) {
      return false;
    } else if (predicates.size() == 1) {
      out = std::move(predicates[0]);
      return true;
    }
    auto result = is_and ? paimon::PredicateBuilder::And(predicates)
                         : paimon::PredicateBuilder::Or(predicates);
    if (!result.ok()) {
      OBEXT_LOG_INFO(host_, "predicate pushdown: compound conversion skipped: %s",
                     result.status().ToString().c_str());
      return false;
    }
    out = std::move(result).value();
    return true;
  }

  bool ParseNot(const rapidjson::Value& node,
                std::shared_ptr<paimon::Predicate>& out)
  {
    const rapidjson::Value* children = node_children(node);
    std::shared_ptr<paimon::Predicate> child;
    if (children == nullptr || children->Size() != 1
        || !Parse((*children)[0], child) || child == nullptr) {
      return false;
    }
    auto result = paimon::PredicateBuilder::Not(child);
    if (!result.ok()) {
      OBEXT_LOG_INFO(host_, "predicate pushdown: NOT conversion skipped: %s",
                     result.status().ToString().c_str());
      return false;
    }
    out = std::move(result).value();
    return true;
  }

  bool ParseComparison(const rapidjson::Value& node,
                       std::shared_ptr<paimon::Predicate>& out)
  {
    const rapidjson::Value* children = node_children(node);
    std::string op;
    std::string field_name;
    int32_t field_index = -1;
    paimon::FieldType field_type = paimon::FieldType::UNKNOWN;
    if (children == nullptr || children->Size() != 2
        || !node_str_field(node, OB_EXT_K_OP, op)
        || !ResolveColumn((*children)[0], field_index, field_name, field_type)) {
      return false;
    }
    paimon::Literal literal(field_type);
    if (!ConvertLiteral((*children)[1], field_type, literal)) {
      return false;
    }
    if (op == "eq") {
      out = paimon::PredicateBuilder::Equal(field_index, field_name, field_type, literal);
    } else if (op == "ne") {
      out = paimon::PredicateBuilder::NotEqual(field_index, field_name, field_type, literal);
    } else if (op == "lt") {
      out = paimon::PredicateBuilder::LessThan(field_index, field_name, field_type, literal);
    } else if (op == "le") {
      out = paimon::PredicateBuilder::LessOrEqual(field_index, field_name, field_type, literal);
    } else if (op == "gt") {
      out = paimon::PredicateBuilder::GreaterThan(field_index, field_name, field_type, literal);
    } else if (op == "ge") {
      out = paimon::PredicateBuilder::GreaterOrEqual(field_index, field_name, field_type, literal);
    }
    return out != nullptr;
  }

  bool ParseIn(const rapidjson::Value& node,
               const bool is_not_in,
               std::shared_ptr<paimon::Predicate>& out)
  {
    const rapidjson::Value* children = node_children(node);
    std::string field_name;
    int32_t field_index = -1;
    paimon::FieldType field_type = paimon::FieldType::UNKNOWN;
    if (children == nullptr || children->Size() < 2
        || !ResolveColumn((*children)[0], field_index, field_name, field_type)) {
      return false;
    }
    std::vector<paimon::Literal> literals;
    literals.reserve(children->Size() - 1);
    for (rapidjson::SizeType i = 1; i < children->Size(); ++i) {
      paimon::Literal literal(field_type);
      if (!ConvertLiteral((*children)[i], field_type, literal)) {
        return false;
      }
      literals.push_back(std::move(literal));
    }
    out = is_not_in
              ? paimon::PredicateBuilder::NotIn(
                    field_index, field_name, field_type, literals)
              : paimon::PredicateBuilder::In(
                    field_index, field_name, field_type, literals);
    return out != nullptr;
  }

  bool ParseNullCheck(const rapidjson::Value& node,
                      const bool is_not_null,
                      std::shared_ptr<paimon::Predicate>& out)
  {
    const rapidjson::Value* children = node_children(node);
    std::string field_name;
    int32_t field_index = -1;
    paimon::FieldType field_type = paimon::FieldType::UNKNOWN;
    if (children == nullptr || children->Size() != 1
        || !ResolveColumn((*children)[0], field_index, field_name, field_type)) {
      return false;
    }
    out = is_not_null
              ? paimon::PredicateBuilder::IsNotNull(field_index, field_name, field_type)
              : paimon::PredicateBuilder::IsNull(field_index, field_name, field_type);
    return out != nullptr;
  }

 private:
  std::shared_ptr<paimon::Schema> schema_;
  const std::vector<int32_t>& read_field_ids_;
  std::vector<std::string> field_names_;
  const ObExtTableHostApi* host_;
};

static bool parse_predicate_json(
    const char* json,
    const std::shared_ptr<paimon::Schema>& schema,
    const std::vector<int32_t>& read_field_ids,
    std::shared_ptr<paimon::Predicate>& out,
    const ObExtTableHostApi* host)
{
  out.reset();
  if (is_empty_json(json)) {
    return true;
  }
  rapidjson::Document doc;
  doc.Parse(json);
  if (doc.HasParseError() || !doc.IsObject()) {
    OBEXT_LOG_WARN(host, "parse_predicate_json: invalid predicate json");
    return false;
  }
  PredicateJsonParser parser(schema, read_field_ids, host);
  return parser.Parse(doc, out);
}

struct PlanPinState {
  std::optional<int64_t> snapshot_id;
  int64_t schema_id = -1;
  std::shared_ptr<paimon::TableSchema> schema;
};

int read_schema_at_latest_snapshot(const std::shared_ptr<paimon::FileSystem>& fs,
                                   const char* table_uri,
                                   const std::map<std::string, std::string>& options,
                                   const ObExtTableHostApi* host, std::string& out_schema_json,
                                   bool& out_got_schema, std::optional<int64_t>& out_snapshot_id)
{
  int ret = OB_EXT_SUCCESS;
  // Align T0 with plan_create (T1): schema AS OF latest snapshot, not bare LatestSchema().
  out_got_schema = false;
  const std::string branch = paimon::BranchManager::NormalizeBranch(
      options.count(paimon::Options::BRANCH) > 0 ? options.at(paimon::Options::BRANCH) : "");
  paimon::SnapshotManager snapshot_manager(fs, table_uri, branch);
  auto snap_ret = snapshot_manager.LatestSnapshot();
  if (!snap_ret.ok()) {
    ret = OBEXT_FAIL_STATUS(snap_ret.status(), host, "load_schema: LatestSnapshot");
  } else if (snap_ret.value().has_value()) {
    const paimon::Snapshot& snap = snap_ret.value().value();
    out_snapshot_id = snap.Id();
    paimon::SchemaManager schema_manager(fs, table_uri, branch);
    auto pinned_schema_ret = schema_manager.ReadSchema(snap.SchemaId());
    if (pinned_schema_ret.ok()) {
      auto json_ret = pinned_schema_ret.value()->GetJsonSchema();
      if (json_ret.ok()) {
        out_schema_json = std::move(json_ret).value();
        out_got_schema = true;
      }
    }
    if (!out_got_schema) {
      OBEXT_LOG_INFO(host,
                     "load_schema: read schema (id=%ld) at snapshot %ld failed; "
                     "fall back to the latest schema",
                     (long)snap.SchemaId(), (long)snap.Id());
    }
  }
  return ret;
}

int read_latest_table_schema_json(const std::shared_ptr<paimon::FileSystem>& fs,
                                  const char* table_uri, const ObExtTableHostApi* host,
                                  std::string& out_schema_json)
{
  int ret = OB_EXT_SUCCESS;
  auto table_ret = paimon::Table::Create(fs, table_uri, paimon::Identifier(table_uri));
  if (!table_ret.ok()) {
    ret = OBEXT_FAIL_STATUS(table_ret.status(), host, "load_schema: Table::Create");
  } else {
    auto latest_schema = table_ret.value()->LatestSchema();
    if (latest_schema == nullptr) {
      OBEXT_LOG_WARN(host, "load_schema: table has no schema");
      ret = OB_EXT_ENTRY_NOT_EXIST;
    } else {
      auto schema_ret = latest_schema->GetJsonSchema();
      if (!schema_ret.ok()) {
        ret = OBEXT_FAIL_STATUS(schema_ret.status(), host, "load_schema: GetJsonSchema");
      } else {
        out_schema_json = std::move(schema_ret).value();
      }
    }
  }
  return ret;
}

int pin_plan_to_latest_snapshot(const std::shared_ptr<paimon::FileSystem>& fs,
                                const char* table_uri, std::map<std::string, std::string>& options,
                                const ObExtTableHostApi* host, PlanPinState& pin)
{
  int ret = OB_EXT_SUCCESS;
  // Pin scan to the current latest snapshot so plan/execute read one snapshot.
  const std::string branch = paimon::BranchManager::NormalizeBranch(
      options.count(paimon::Options::BRANCH) > 0 ? options[paimon::Options::BRANCH] : "");
  paimon::SnapshotManager snapshot_manager(fs, table_uri, branch);
  auto snap_ret = snapshot_manager.LatestSnapshot();
  if (!snap_ret.ok()) {
    ret = OBEXT_FAIL_STATUS(snap_ret.status(), host, "plan_create: LatestSnapshot");
  } else if (snap_ret.value().has_value()) {
    const paimon::Snapshot& snap = snap_ret.value().value();
    pin.snapshot_id = snap.Id();
    pin.schema_id = snap.SchemaId();
    options[paimon::Options::SCAN_SNAPSHOT_ID] = std::to_string(snap.Id());
    paimon::SchemaManager schema_manager(fs, table_uri, branch);
    auto pinned_schema_ret = schema_manager.ReadSchema(snap.SchemaId());
    if (!pinned_schema_ret.ok()) {
      // Hard error, same as reader_create: the pinned schema is what the
      // predicate and the readers resolve against — silently falling back to
      // the latest schema could resolve a predicate against the wrong schema
      // and prune files the query must keep.
      ret = OBEXT_FAIL_STATUS(pinned_schema_ret.status(), host, "plan_create: ReadSchema");
    } else {
      pin.schema = std::move(pinned_schema_ret).value();
    }
  }
  return ret;
}

int apply_plan_scan_predicate(paimon::ScanContextBuilder& builder, const char* predicate_json,
                              const std::shared_ptr<paimon::FileSystem>& fs, const char* table_uri,
                              const std::shared_ptr<paimon::TableSchema>& pinned_schema,
                              const ObExtTableHostApi* host)
{
  int ret = OB_EXT_SUCCESS;
  if (!is_empty_json(predicate_json)) {
    std::shared_ptr<paimon::Schema> pred_schema = pinned_schema;
    if (pred_schema == nullptr) {
      auto table_ret = paimon::Table::Create(fs, table_uri, paimon::Identifier(table_uri));
      if (!table_ret.ok()) {
        ret = OBEXT_FAIL_STATUS(table_ret.status(), host, "plan_create: predicate Table::Create");
      } else {
        pred_schema = table_ret.value()->LatestSchema();
      }
    }
    if (OB_EXT_SUCC(ret)) {
      std::shared_ptr<paimon::Predicate> predicate;
      const std::vector<int32_t> all_fields;
      if (pred_schema == nullptr) {
        OBEXT_LOG_INFO(host, "plan_create: no latest schema; skip scan pushdown");
      } else if (parse_predicate_json(predicate_json, pred_schema, all_fields, predicate, host) &&
                 predicate != nullptr) {
        builder.SetPredicate(predicate);
      } else {
        OBEXT_LOG_INFO(host, "plan_create: predicate is not convertible; skip scan pushdown");
      }
    }
  }
  return ret;
}

int create_scan_plan(paimon::ScanContextBuilder& builder, const ObExtTableHostApi* host,
                     std::shared_ptr<paimon::Plan>& plan)
{
  int ret = OB_EXT_SUCCESS;
  auto ctx_ret = builder.Finish();
  if (!ctx_ret.ok()) {
    ret = OBEXT_FAIL_STATUS(ctx_ret.status(), host, "plan_create: ScanContextBuilder.Finish");
  } else {
    OBEXT_LOG_INFO(host, "plan_create: before TableScan::Create");
    auto scan_ret = paimon::TableScan::Create(std::move(ctx_ret).value());
    if (!scan_ret.ok()) {
      ret = OBEXT_FAIL_STATUS(scan_ret.status(), host, "plan_create: TableScan::Create");
    } else {
      OBEXT_LOG_INFO(host, "plan_create: before CreatePlan");
      auto plan_ret = scan_ret.value()->CreatePlan();
      if (!plan_ret.ok()) {
        ret = OBEXT_FAIL_STATUS(plan_ret.status(), host, "plan_create: CreatePlan");
      } else {
        OBEXT_LOG_INFO(host, "plan_create: CreatePlan ok, splits=%zu",
                       plan_ret.value()->Splits().size());
        plan = std::move(plan_ret).value();
      }
    }
  }
  return ret;
}

int build_plan_tasks_json(const std::shared_ptr<paimon::Plan>& plan,
                          const std::shared_ptr<paimon::MemoryPool>& pool,
                          const ObExtTableHostApi* host, char** out_tasks_json, int32_t* out_len)
{
  int ret = OB_EXT_SUCCESS;
  rapidjson::Document doc;
  doc.SetObject();
  rapidjson::Document::AllocatorType& al = doc.GetAllocator();
  rapidjson::Value tasks(rapidjson::kArrayType);
  const auto& splits = plan->Splits();
  for (auto it = splits.begin(); OB_EXT_SUCC(ret) && it != splits.end(); ++it) {
    const auto& split = *it;
    auto bytes_ret = paimon::Split::Serialize(split, pool);
    if (!bytes_ret.ok()) {
      ret = OBEXT_FAIL_STATUS(bytes_ret.status(), host, "plan_create: Split::Serialize");
    } else {
      const std::string bytes = std::move(bytes_ret).value();
      const std::string payload = base64_encode(bytes.data(), static_cast<int32_t>(bytes.size()));

      rapidjson::Value task(rapidjson::kObjectType);
      // Feed OB's optimizer real per-task stats (cardinality / auto-dop depend on
      // them; -1 collapses the row estimate to 1 and serializes PX plans).
      // DataSplit carries per-file row_count/file_size from the manifest;
      // non-data splits keep the -1 "unknown" fallback.
      int64_t row_count = -1;
      int64_t byte_size = -1;
      const std::shared_ptr<paimon::DataSplit> data_split =
          std::dynamic_pointer_cast<paimon::DataSplit>(split);
      if (data_split != nullptr) {
        row_count = 0;
        byte_size = 0;
        for (const auto& file_meta : data_split->GetFileList()) {
          row_count += file_meta.row_count;
          byte_size += file_meta.file_size;
        }
      }
      task.AddMember(rapidjson::StringRef(OB_EXT_K_ROW_COUNT), row_count, al);
      task.AddMember(rapidjson::StringRef(OB_EXT_K_BYTE_SIZE), byte_size, al);
      task.AddMember(rapidjson::StringRef(OB_EXT_K_FILES), rapidjson::Value(rapidjson::kArrayType),
                     al);
      task.AddMember(rapidjson::StringRef(OB_EXT_K_SPLITTABLE), false, al);
      task.AddMember(rapidjson::StringRef(OB_EXT_K_PAYLOAD_B64),
                     rapidjson::Value(payload.c_str(),
                                      static_cast<rapidjson::SizeType>(payload.size()), al),
                     al);
      tasks.PushBack(task, al);
    }
  }
  if (OB_EXT_SUCC(ret)) {
    doc.AddMember(rapidjson::StringRef(OB_EXT_K_TASKS), tasks, al);
    rapidjson::StringBuffer sb;
    rapidjson::Writer<rapidjson::StringBuffer> writer(sb);
    doc.Accept(writer);
    ret = copy_string_to_host(host, sb.GetString(), sb.GetSize(), out_tasks_json, out_len);
  }
  return ret;
}

int apply_reader_predicate(paimon::ReadContextBuilder& builder,
                           const ObExtTableReaderWorkerState* worker,
                           const std::string& predicate_json,
                           const std::shared_ptr<paimon::TableSchema>& pinned_schema,
                           const ObExtTableHostApi* host)
{
  int ret = OB_EXT_SUCCESS;
  if (!is_empty_json(predicate_json.c_str())) {
    std::shared_ptr<paimon::Schema> pred_schema = pinned_schema;
    if (pred_schema == nullptr) {
      auto table_ret = paimon::Table::Create(
          worker->file_system_,
          worker->table_uri_,
          paimon::Identifier(worker->table_uri_));
      if (!table_ret.ok()) {
        ret = OBEXT_FAIL_STATUS(table_ret.status(), host,
                                "reader_open_scan: predicate Table::Create");
      } else {
        pred_schema = table_ret.value()->LatestSchema();
      }
    }
    if (OB_EXT_SUCC(ret)) {
      std::shared_ptr<paimon::Predicate> predicate;
      if (pred_schema == nullptr) {
        OBEXT_LOG_INFO(host, "reader_open_scan: no latest schema; skip reader pushdown");
      } else if (parse_predicate_json(predicate_json.c_str(), pred_schema,
                                      worker->field_ids_, predicate, host)
                 && predicate != nullptr) {
        builder.SetPredicate(predicate);
      } else {
        OBEXT_LOG_INFO(host,
                       "reader_open_scan: predicate is not convertible; skip reader pushdown");
      }
    }
  }
  return ret;
}

int build_table_read(const ObExtTableReaderWorkerState* worker,
                     const std::string& predicate_json,
                     const ObExtTableHostApi* host,
                     std::unique_ptr<paimon::TableRead>& out)
{
  int ret = OB_EXT_SUCCESS;
  out.reset();
  // Version consistency: the split already IS the pinned snapshot; re-resolve only
  // the read schema from the injected schema_id (SchemaManager is cached).
  std::shared_ptr<paimon::TableSchema> pinned_schema;
  if (worker->schema_id_ >= 0) {
    const std::string branch = paimon::BranchManager::NormalizeBranch(
        worker->options_.count(paimon::Options::BRANCH) > 0
            ? worker->options_.at(paimon::Options::BRANCH)
            : "");
    paimon::SchemaManager schema_manager(
        worker->file_system_, worker->table_uri_, branch);
    auto schema_ret = schema_manager.ReadSchema(worker->schema_id_);
    if (!schema_ret.ok()) {
      ret = OBEXT_FAIL_STATUS(schema_ret.status(), host, "reader_open_scan: ReadSchema");
    } else {
      pinned_schema = std::move(schema_ret).value();
    }
  }

  paimon::ReadContextBuilder builder(worker->table_uri_);
  if (OB_EXT_SUCC(ret)) {
    builder.SetOptions(worker->options_)
        .WithMemoryPool(worker->pool_)
        .WithExecutor(worker->executor_)
        .WithFileSystem(worker->file_system_);
    if (pinned_schema != nullptr) {
      auto js_ret = pinned_schema->GetJsonSchema();
      if (!js_ret.ok()) {
        ret = OBEXT_FAIL_STATUS(js_ret.status(), host, "reader_open_scan: GetJsonSchema");
      } else {
        builder.SetTableSchema(std::move(js_ret).value());
      }
    }
    if (OB_EXT_SUCC(ret) && !worker->field_ids_.empty()) {
      builder.SetReadFieldIds(worker->field_ids_);
    }
    if (OB_EXT_SUCC(ret)) {
      ret = apply_reader_predicate(builder, worker, predicate_json, pinned_schema, host);
    }
  }
  if (OB_EXT_SUCC(ret)) {
    auto read_ctx_ret = builder.Finish();
    if (!read_ctx_ret.ok()) {
      ret = OBEXT_FAIL_STATUS(read_ctx_ret.status(), host,
                              "reader_open_scan: ReadContextBuilder.Finish");
    } else {
      auto table_read_ret = paimon::TableRead::Create(std::move(read_ctx_ret).value());
      if (!table_read_ret.ok()) {
        ret = OBEXT_FAIL_STATUS(table_read_ret.status(), host,
                                "reader_open_scan: TableRead::Create");
      } else {
        out = std::move(table_read_ret).value();
      }
    }
  }
  return ret;
}

int open_reader_split(const ObExtTableReaderWorkerState* worker,
                      const ObExtTableReaderScanState* scan,
                      ObExtTableReaderTaskState* task,
                      const ObExtTableHostApi* host,
                      const std::string& split_bytes)
{
  int ret = OB_EXT_SUCCESS;
  paimon::TableRead* table_read = scan != nullptr ? scan->table_read_.get() : nullptr;
  if (table_read == nullptr) {
    ret = OB_EXT_ERR_UNEXPECTED;
    OBEXT_LOG_WARN(host,
                   "reader_open_task: scan is configured without a TableRead");
  } else {
    auto split_ret = paimon::Split::Deserialize(
        split_bytes.data(), split_bytes.size(), worker->pool_);
    if (!split_ret.ok()) {
      ret = OBEXT_FAIL_STATUS(split_ret.status(), host,
                              "reader_open_task: Split::Deserialize");
    } else {
      std::shared_ptr<paimon::Split> split = std::move(split_ret).value();
      auto reader_ret = table_read->CreateReader(split);
      if (!reader_ret.ok()) {
        ret = OBEXT_FAIL_STATUS(reader_ret.status(), host,
                                "reader_open_task: CreateReader");
      } else {
        task->split_ = std::move(split);
        task->batch_reader_ = std::move(reader_ret).value();
      }
    }
  }
  return ret;
}

void close_reader_task(ObExtTableReaderTaskState *task)
{
  if (task != nullptr) {
    const bool had_task = task->batch_reader_ != nullptr || task->split_ != nullptr;
    if (task->batch_reader_ != nullptr) {
      task->batch_reader_->Close();
      task->batch_reader_.reset();
    }
    task->split_.reset();
    if (had_task) {
      ++task->task_close_count_;
    }
  }
}

}  // namespace

extern "C" {

static const char* obext_plugin_name(void) { return "Paimon C++ plugin"; }
static const char* obext_plugin_version(void) { return "0.2.0"; }
static const char* obext_format_name(void) { return "PAIMON"; }

static int obext_recognize_table(const char* table_uri, const char* recognize_json,
                                 const ObExtTableHostApi* host)
{
  ob_ext_paimon::CurrentHost::Scope host_scope(host);
  int ret = OB_EXT_ENTRY_NOT_EXIST;
  if (!is_empty_json(recognize_json)) {
    rapidjson::Document doc;
    doc.Parse(recognize_json);
    if (!doc.HasParseError() && doc.IsObject()
        && (recognize_filesystem_paimon(table_uri, doc, host)
            || recognize_hms_paimon(doc))) {
      ret = OB_EXT_SUCCESS;
    }
  }
  return ret;
}

static int obext_load_schema(const char* table_uri, const char* options_json,
                             const ObExtTableHostApi* host,
                             char** out_schema_json, int32_t* out_len)
{
  ob_ext_paimon::CurrentHost::Scope host_scope(host);
  int ret = OB_EXT_SUCCESS;
  if (table_uri == nullptr || host == nullptr || out_schema_json == nullptr || out_len == nullptr) {
    OBEXT_LOG_WARN(host, "load_schema: invalid argument, table_uri=%p host=%p",
                   (const void*)table_uri, (const void*)host);
    ret = OB_EXT_INVALID_ARGUMENT;
  } else {
    *out_schema_json = nullptr;
    *out_len = 0;
    try {
      std::map<std::string, std::string> options;
      std::string paimon_schema_json;
      std::string json;
      bool got_schema = false;
      std::optional<int64_t> snapshot_id_at_load;
      std::shared_ptr<paimon::FileSystem> fs;

      if (OB_EXT_SUCCESS != (ret = parse_options_json(options_json, options, host))) {
        OBEXT_LOG_WARN(host, "load_schema: parse options_json failed, ret=%d", ret);
      }
      if (OB_EXT_SUCC(ret)) {
        auto executor = ob_ext_paimon::make_executor(host);
        fs = ob_ext_paimon::make_file_system(host, executor);
        ret = read_schema_at_latest_snapshot(fs, table_uri, options, host, paimon_schema_json,
                                             got_schema, snapshot_id_at_load);
      }
      if (OB_EXT_SUCC(ret) && !got_schema) {
        ret = read_latest_table_schema_json(fs, table_uri, host, paimon_schema_json);
      }
      if (OB_EXT_SUCC(ret) &&
          OB_EXT_SUCCESS != (ret = build_schema_json(
                                 paimon_schema_json, json,
                                 got_schema ? snapshot_id_at_load : std::nullopt))) {
        OBEXT_LOG_WARN(host, "load_schema: build schema json failed, ret=%d", ret);
      }
      if (OB_EXT_SUCC(ret)) {
        ret = copy_string_to_host(host, json, out_schema_json, out_len);
      }
    } catch (...) {
      ret = OBEXT_FAIL_EXCEPTION(host, "load_schema");
    }
  }
  return ret;
}

// Compare T0 catalog_context (in options_json) with the schema_id pinned at T1.
// Returns OB_EXT_OLD_SCHEMA_VERSION on drift; absent fields => skip (degrade).
static int check_catalog_context_drift(const char* options_json,
                                       int64_t pinned_schema_id,
                                       const ObExtTableHostApi* host)
{
  int ret = OB_EXT_SUCCESS;
  if (pinned_schema_id >= 0 && !is_empty_json(options_json)) {
    rapidjson::Document doc;
    doc.Parse(options_json);
    if (doc.HasParseError() || !doc.IsObject()) {
      // options_json is OB-built and should always be well-formed; a parse
      // failure here means something corrupted it (e.g. an unterminated buffer
      // upstream) and the drift check is being skipped — say so, loudly.
      OBEXT_LOG_WARN(host,
                     "check_catalog_context_drift: options_json is not a JSON object; "
                     "drift check skipped");
    } else {
      const rapidjson::Value::ConstMemberIterator cit =
          doc.FindMember(OB_EXT_K_CATALOG_CONTEXT);
      if (cit != doc.MemberEnd() && cit->value.IsObject()) {
        const rapidjson::Value::ConstMemberIterator sid =
            cit->value.FindMember(kCatalogCtxSchemaId);
        if (sid != cit->value.MemberEnd() && sid->value.IsInt64()) {
          const int64_t t0_schema_id = sid->value.GetInt64();
          if (t0_schema_id != pinned_schema_id) {
            OBEXT_LOG_WARN(host,
                           "plan_create: catalog schema drift T0=%ld T1=%ld",
                           (long)t0_schema_id, (long)pinned_schema_id);
            ret = OB_EXT_OLD_SCHEMA_VERSION;
          }
        }
      }
    }
  }
  return ret;
}

static int obext_plan_create(const char* table_uri, const char* options_json,
                             const char* partition_filter_json, const char* predicate_json,
                             int64_t limit, int32_t /*desired_task_count*/,
                             const ObExtTableHostApi* host, char** out_tasks_json, int32_t* out_len)
{
  ob_ext_paimon::CurrentHost::Scope host_scope(host);
  int ret = OB_EXT_SUCCESS;
  if (table_uri == nullptr || host == nullptr || out_tasks_json == nullptr || out_len == nullptr) {
    OBEXT_LOG_WARN(host, "plan_create: invalid argument, table_uri=%p host=%p",
                   (const void*)table_uri, (const void*)host);
    ret = OB_EXT_INVALID_ARGUMENT;
  } else {
    *out_tasks_json = nullptr;
    *out_len = 0;
    try {
      std::map<std::string, std::string> options;
      PlanPinState pin;
      std::shared_ptr<paimon::MemoryPool> pool;
      std::shared_ptr<paimon::Executor> executor;
      std::shared_ptr<paimon::FileSystem> fs;
      std::shared_ptr<paimon::Plan> plan;

      if (OB_EXT_SUCCESS != (ret = parse_options_json(options_json, options, host))) {
        OBEXT_LOG_WARN(host, "plan_create: parse options_json failed, ret=%d", ret);
      }
      if (OB_EXT_SUCC(ret)) {
        pool = make_pool_or_default(host);
        executor = ob_ext_paimon::make_executor(host);
        fs = ob_ext_paimon::make_file_system(host, executor);
        ret = pin_plan_to_latest_snapshot(fs, table_uri, options, host, pin);
      }
      if (OB_EXT_SUCC(ret)) {
        ret = check_catalog_context_drift(options_json, pin.schema_id, host);
      }
      if (OB_EXT_SUCC(ret)) {
        paimon::ScanContextBuilder builder(table_uri);
        builder.SetOptions(options).WithMemoryPool(pool).WithExecutor(executor).WithFileSystem(fs);
        if (limit >= 0) {
          builder.SetLimit(
              static_cast<int32_t>(std::min<int64_t>(limit, std::numeric_limits<int32_t>::max())));
        }
        // Partition pruning: flatten partition_filter_json into OR-of-AND equality maps;
        // non-equality content skips SetPartitionFilter (OB residual filter still correct).
        std::vector<std::map<std::string, std::string>> partition_filters;
        if (parse_partition_filter(partition_filter_json, partition_filters, host) &&
            !partition_filters.empty()) {
          builder.SetPartitionFilter(partition_filters);
        }
        ret = apply_plan_scan_predicate(builder, predicate_json, fs, table_uri, pin.schema, host);
        if (OB_EXT_SUCC(ret)) {
          ret = create_scan_plan(builder, host, plan);
        }
      }
      if (OB_EXT_SUCC(ret)) {
        ret = build_plan_tasks_json(plan, pool, host, out_tasks_json, out_len);
      }
    } catch (...) {
      ret = OBEXT_FAIL_EXCEPTION(host, "plan_create");
    }
  }
  return ret;
}

static int obext_reader_create(
    const ObExtTableHostApi *host,
    const char *table_uri,
    const char *options_json,
    const char *read_projection_json,
    ObExtTableReaderWorkerStateRef *out_worker,
    ObExtTableReaderScanStateRef *out_scan,
    ObExtTableReaderTaskStateRef *out_task)
{
  ob_ext_paimon::CurrentHost::Scope host_scope(host);
  int ret = OB_EXT_SUCCESS;
  if (out_worker != nullptr) {
    *out_worker = nullptr;
  }
  if (out_scan != nullptr) {
    *out_scan = nullptr;
  }
  if (out_task != nullptr) {
    *out_task = nullptr;
  }
  if (host == nullptr || table_uri == nullptr || out_worker == nullptr
      || out_scan == nullptr || out_task == nullptr) {
    OBEXT_LOG_WARN(
        host,
        "reader_create: invalid argument, host=%p table_uri=%p out_worker=%p "
        "out_scan=%p out_task=%p",
        (const void *)host,
        (const void *)table_uri,
        (void *)out_worker,
        (void *)out_scan,
        (void *)out_task);
    ret = OB_EXT_INVALID_ARGUMENT;
  } else {
    try {
      std::unique_ptr<ObExtTableReaderWorkerState> worker(new (std::nothrow)
                                                              ObExtTableReaderWorkerState());
      std::unique_ptr<ObExtTableReaderScanState> scan(new (std::nothrow)
                                                          ObExtTableReaderScanState());
      std::unique_ptr<ObExtTableReaderTaskState> task(new (std::nothrow)
                                                          ObExtTableReaderTaskState());
      if (worker == nullptr || scan == nullptr || task == nullptr) {
        OBEXT_LOG_WARN(host, "reader_create: failed to allocate reader states");
        ret = OB_EXT_ALLOCATE_MEMORY_FAILED;
      }
      if (OB_EXT_SUCC(ret)) {
        worker->host_ = host;
        worker->pool_ = make_pool_or_default(host);
        worker->executor_ = ob_ext_paimon::make_executor(host);
        worker->file_system_ = ob_ext_paimon::make_file_system(host, worker->executor_);
        if (worker->pool_ == nullptr || worker->executor_ == nullptr
            || worker->file_system_ == nullptr) {
          OBEXT_LOG_WARN(host, "reader_create: failed to create reusable reader resources");
          ret = OB_EXT_ALLOCATE_MEMORY_FAILED;
        }
      }
      // Reader-lifetime configuration: parse once, store in worker state.
      if (OB_EXT_SUCC(ret)) {
        worker->table_uri_ = table_uri;
        if (OB_EXT_SUCCESS
            != (ret = parse_options_json(options_json, worker->options_, host))) {
          OBEXT_LOG_WARN(host, "reader_create: parse options_json failed, ret=%d", ret);
        } else if (OB_EXT_SUCCESS
                   != (ret = extract_options_schema_id(options_json, worker->schema_id_, host))) {
          OBEXT_LOG_WARN(host, "reader_create: extract schema_id failed, ret=%d", ret);
        } else if (OB_EXT_SUCCESS
                   != (ret = parse_field_ids_projection(
                           read_projection_json, worker->field_ids_, host))) {
          OBEXT_LOG_WARN(host, "reader_create: parse read_projection failed, ret=%d", ret);
        }
      }
      if (OB_EXT_SUCC(ret)) {
        *out_worker = worker.release();
        *out_scan = scan.release();
        *out_task = task.release();
      }
    } catch (...) {
      ret = OBEXT_FAIL_EXCEPTION(host, "reader_create");
    }
  }
  return ret;
}

static int obext_reader_open_scan(
    ObExtTableReaderWorkerStateConstRef worker,
    ObExtTableReaderScanStateRef scan,
    const char *predicate_json)
{
  const ObExtTableHostApi *host = worker != nullptr ? worker->host_ : nullptr;
  ob_ext_paimon::CurrentHost::Scope host_scope(host);
  int ret = OB_EXT_SUCCESS;
  if (worker == nullptr || scan == nullptr) {
    OBEXT_LOG_WARN(
        host,
        "reader_open_scan: invalid argument, worker=%p scan=%p",
        (const void *)worker,
        (const void *)scan);
    ret = OB_EXT_INVALID_ARGUMENT;
  } else {
    try {
      scan->table_read_.reset();
      ret = build_table_read(
          worker, predicate_json != nullptr ? predicate_json : "", host, scan->table_read_);
    } catch (...) {
      ret = OBEXT_FAIL_EXCEPTION(host, "reader_open_scan");
    }
  }
  return ret;
}

static int obext_reader_open_task(
    ObExtTableReaderWorkerStateConstRef worker,
    ObExtTableReaderScanStateConstRef scan,
    ObExtTableReaderTaskStateRef task,
    const char* task_json,
    int32_t task_len,
    uint64_t /*start_row*/,
    uint64_t /*row_count*/)
{
  const ObExtTableHostApi* host = worker != nullptr ? worker->host_ : nullptr;
  ob_ext_paimon::CurrentHost::Scope host_scope(host);
  int ret = OB_EXT_SUCCESS;
  if (worker == nullptr || scan == nullptr || task == nullptr
      || task_json == nullptr || task_len <= 0) {
    OBEXT_LOG_WARN(host,
                   "reader_open_task: invalid argument, worker=%p scan=%p task=%p "
                   "task_json=%p task_len=%d",
                   (const void*)worker, (const void*)scan, (const void*)task,
                   (const void*)task_json, (int)task_len);
    ret = OB_EXT_INVALID_ARGUMENT;
  } else {
    try {
      // Reuse the persistent task-state object without carrying split-local
      // members across task boundaries.
      close_reader_task(task);
      task->host_ = worker->host_;

      std::string split_bytes;
      if (OB_EXT_SUCCESS
          != (ret = parse_task_payload_json(task_json, task_len, split_bytes, host))) {
        OBEXT_LOG_WARN(host, "reader_open_task: parse task_json failed, ret=%d", ret);
      } else {
        // Every task opens a new Split and BatchReader on the scan's TableRead.
        ret = open_reader_split(worker, scan, task, host, split_bytes);
      }
      if (OB_EXT_SUCC(ret)) {
        ++task->task_open_count_;
      }
    } catch (...) {
      ret = OBEXT_FAIL_EXCEPTION(host, "reader_open_task");
    }
    if (!OB_EXT_SUCC(ret)) {
      // A failed open never leaves a partially active task.
      close_reader_task(task);
    }
  }
  return ret;
}

static int obext_reader_next_batch(ObExtTableReaderWorkerStateConstRef worker,
                                   ObExtTableReaderTaskStateRef task,
                                   struct ArrowArray* arr,
                                   struct ArrowSchema* sch)
{
  const ObExtTableHostApi* host = worker != nullptr ? worker->host_ : nullptr;
  ob_ext_paimon::CurrentHost::Scope host_scope(host);
  int ret = OB_EXT_SUCCESS;
  paimon::BatchReader* batch_reader =
      task != nullptr ? task->batch_reader_.get() : nullptr;
  if (worker == nullptr || task == nullptr || batch_reader == nullptr
      || arr == nullptr || sch == nullptr) {
    OBEXT_LOG_WARN(host,
                   "reader_next_batch: invalid argument, worker=%p task=%p "
                   "batch_reader=%p",
                   (const void*)worker, (const void*)task, (const void*)batch_reader);
    ret = OB_EXT_INVALID_ARGUMENT;
  } else {
    try {
      auto batch_ret = batch_reader->NextBatch();
      if (!batch_ret.ok()) {
        ret = OBEXT_FAIL_STATUS(batch_ret.status(), host, "reader_next_batch: NextBatch");
      } else {
        auto batch = std::move(batch_ret).value();
        if (paimon::BatchReader::IsEofBatch(batch)) {
          ret = 1;
        } else {
          ArrowArrayMove(batch.first.get(), arr);
          ArrowSchemaMove(batch.second.get(), sch);
        }
      }
    } catch (...) {
      ret = OBEXT_FAIL_EXCEPTION(host, "reader_next_batch");
    }
  }
  return ret;
}

static void obext_reader_close_task(ObExtTableReaderTaskStateRef task)
{
  const ObExtTableHostApi *host = task != nullptr ? task->host_ : nullptr;
  ob_ext_paimon::CurrentHost::Scope host_scope(host);
  close_reader_task(task);
}

static void obext_reader_close_scan(ObExtTableReaderWorkerStateConstRef worker,
                                    ObExtTableReaderScanStateRef scan)
{
  const ObExtTableHostApi* host = worker != nullptr ? worker->host_ : nullptr;
  ob_ext_paimon::CurrentHost::Scope host_scope(host);
  // End the scan: release its read pipeline; the backing object survives.
  if (worker == nullptr || scan == nullptr) {
    OBEXT_LOG_WARN(host, "reader_close_scan: invalid argument, worker=%p scan=%p",
                   (const void*)worker, (const void*)scan);
  } else {
    scan->table_read_.reset();
  }
}

static void obext_reader_close(
    ObExtTableReaderWorkerStateRef worker,
    ObExtTableReaderScanStateRef scan,
    ObExtTableReaderTaskStateRef task)
{
  const ObExtTableHostApi *host = worker != nullptr ? worker->host_ : nullptr;
  ob_ext_paimon::CurrentHost::Scope host_scope(host);
  // Final iterator boundary: defensively clear the task scope, then release the
  // three backing objects in child-to-parent order.
  close_reader_task(task);
  if (worker != nullptr) {
    OBEXT_LOG_TRACE(
        host,
        "reader lifecycle: task_open=%llu task_close=%llu",
        (unsigned long long)(task != nullptr ? task->task_open_count_ : 0),
        (unsigned long long)(task != nullptr ? task->task_close_count_ : 0));
  }
  delete task;
  delete scan;
  delete worker;
}

// ---- output buffer release ----
// The plugin owns the release of every output JSON buffer it produced via
// copy_string_to_host (which allocates through host->mem.mem_alloc). OB calls these
// destroy callbacks instead of freeing the buffer itself. The buffer was
// allocated with the host allocator, so it is freed back through the same
// allocator. copy_string_to_host ALWAYS allocates len+1 (payload + NUL) while
// `len` here is the payload length, so the free size is len+1 — alloc/free
// sizes stay consistent even for a size-aware host allocator.
static void obext_schema_destroy(char* schema_json, int32_t len,
                                 const ObExtTableHostApi* host)
{
  if (schema_json != nullptr && host != nullptr && host->mem.mem_free != nullptr) {
    host->mem.mem_free(host->ctx, schema_json, static_cast<int64_t>(len) + 1);
  } else if (schema_json != nullptr) {
    // The buffer was host-allocated but the host free slot is unreachable —
    // it is leaked; say so (this should never happen with a well-formed host).
    OBEXT_LOG_WARN(host, "schema_destroy: host mem_free unavailable, output buffer leaked");
  }
}

static void obext_tasks_destroy(char* tasks_json, int32_t len,
                                const ObExtTableHostApi* host)
{
  if (tasks_json != nullptr && host != nullptr && host->mem.mem_free != nullptr) {
    host->mem.mem_free(host->ctx, tasks_json, static_cast<int64_t>(len) + 1);
  } else if (tasks_json != nullptr) {
    OBEXT_LOG_WARN(host, "tasks_destroy: host mem_free unavailable, output buffer leaked");
  }
}

[[maybe_unused]] static void obext_stats_destroy(char* stats_json, int32_t len,
                                const ObExtTableHostApi* host)
{
  if (stats_json != nullptr && host != nullptr && host->mem.mem_free != nullptr) {
    host->mem.mem_free(host->ctx, stats_json, static_cast<int64_t>(len) + 1);
  } else if (stats_json != nullptr) {
    OBEXT_LOG_WARN(host, "stats_destroy: host mem_free unavailable, output buffer leaked");
  }
}

}  // extern "C"

namespace {

void fill_api(ObExtTablePluginApi& a)
{
  a.plugin_name = obext_plugin_name;
  a.plugin_version = obext_plugin_version;
  a.format_name = obext_format_name;
  a.init = nullptr;
  a.deinit = nullptr;
  a.load_schema = obext_load_schema;
  a.plan_create = obext_plan_create;
  a.reader_create = obext_reader_create;
  a.reader_open_scan = obext_reader_open_scan;
  a.reader_open_task = obext_reader_open_task;
  a.reader_next_batch = obext_reader_next_batch;
  a.reader_close_task = obext_reader_close_task;
  a.reader_close_scan = obext_reader_close_scan;
  a.reader_close = obext_reader_close;
  a.schema_destroy = obext_schema_destroy;
  a.tasks_destroy = obext_tasks_destroy;
  a.fetch_statistics = nullptr;
  a.stats_destroy = nullptr;  // no stats emitted yet; no buffer to release
  a.recognize_table = obext_recognize_table;
}

}  // namespace

extern "C" __attribute__((visibility("default")))
const ObExtTablePluginApi* ob_ext_table_plugin_get_api(unsigned int abi_version)
{
  const ObExtTablePluginApi* result = nullptr;
  if (abi_version != OB_EXT_TABLE_PLUGIN_ABI_VERSION) {
    // No host is available here, so the diagnostic goes to stderr with the
    // plugin source location — grep "[paimon] ABI mismatch" to find it.
    std::fprintf(stderr, "[paimon] %s:%d %s: ABI mismatch: requested=%u built=%u\n",
                 __FILE__, __LINE__, __func__, abi_version,
                 (unsigned)OB_EXT_TABLE_PLUGIN_ABI_VERSION);
  } else {
    // Register the paimon->host log bridge once for the whole process so paimon
    // SDK internals route through host->log (and thence OB's logger). Done here
    // (not in a separate init slot, which is NULL) so it is guaranteed before any
    // paimon call. Idempotent (call_once inside).
    ob_ext_paimon::register_paimon_logger_bridge();
    static ObExtTablePluginApi api;
    static std::once_flag flag;
    std::call_once(flag, [&]() { fill_api(api); });
    result = &api;
  }
  return result;
}
