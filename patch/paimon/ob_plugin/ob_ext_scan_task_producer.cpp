// Copyright 2026-present Alibaba Inc.
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

#include "ob_ext_scan_task_producer.h"

#include <algorithm>
#include <cstdint>
#include <optional>
#include <utility>

#include "rapidjson/document.h"
#include "rapidjson/stringbuffer.h"
#include "rapidjson/writer.h"

#include "ob_ext_plugin_host.h"
#include "paimon/common/utils/string_utils.h"
#include "paimon/core/schema/table_schema.h"
#include "paimon/defs.h"
#include "paimon/global_index/indexed_split.h"
#include "paimon/ob_external_table_plugin.h"
#include "paimon/table/source/data_split.h"
#include "paimon/table/source/plan.h"
#include "paimon/table/source/split.h"

namespace ob_ext_paimon
{
namespace
{

struct ObFileScanEntry
{
  std::string file_path;
  int64_t byte_size = 0;
  // Exact manifest row count for this physical file. A plugin split may contain
  // multiple files, so this preserves cardinality when OB lowers the split into
  // file-level optimizer tasks. -1 means not populated or validated.
  int64_t row_count_ = -1;
};

struct PartitionValue
{
  int32_t field_id = -1;
  std::optional<std::string> value;
};

struct ObFileScanDescriptor
{
  std::string file_format;
  std::vector<ObFileScanEntry> files;
};

const char kBase64Alphabet[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

std::string Base64Encode(const char *data, int32_t len)
{
  std::string output;
  if (data == nullptr || len <= 0) {
    return output;
  }
  output.reserve(((static_cast<size_t>(len) + 2) / 3) * 4);
  const unsigned char *bytes = reinterpret_cast<const unsigned char *>(data);
  for (int32_t i = 0; i < len; i += 3) {
    const uint32_t b0 = bytes[i];
    const uint32_t b1 = i + 1 < len ? bytes[i + 1] : 0;
    const uint32_t b2 = i + 2 < len ? bytes[i + 2] : 0;
    const uint32_t triple = (b0 << 16) | (b1 << 8) | b2;
    output.push_back(kBase64Alphabet[(triple >> 18) & 0x3f]);
    output.push_back(kBase64Alphabet[(triple >> 12) & 0x3f]);
    output.push_back(i + 1 < len ? kBase64Alphabet[(triple >> 6) & 0x3f] : '=');
    output.push_back(i + 2 < len ? kBase64Alphabet[triple & 0x3f] : '=');
  }
  return output;
}

bool IsOptionDisabled(const std::map<std::string, std::string> &options, const char *key)
{
  const auto iter = options.find(key);
  if (iter == options.end()) {
    return true;
  }
  const auto parsed = paimon::StringUtils::StringToValue<bool>(iter->second);
  return parsed.has_value() && !parsed.value();
}

bool DetectObFileFormat(const std::string &file_path, std::string &file_format)
{
  if (paimon::StringUtils::EndsWith(file_path, ".parquet")) {
    file_format = "parquet";
    return true;
  }
  if (paimon::StringUtils::EndsWith(file_path, ".orc")) {
    file_format = "orc";
    return true;
  }
  return false;
}

bool HexDigit(char value, int32_t &result)
{
  if (value >= '0' && value <= '9') {
    result = value - '0';
  } else if (value >= 'a' && value <= 'f') {
    result = value - 'a' + 10;
  } else if (value >= 'A' && value <= 'F') {
    result = value - 'A' + 10;
  } else {
    return false;
  }
  return true;
}

bool PercentDecode(const std::string &input, std::string &output)
{
  output.clear();
  output.reserve(input.size());
  for (size_t i = 0; i < input.size(); ++i) {
    if (input[i] != '%') {
      output.push_back(input[i]);
    } else {
      int32_t high = 0;
      int32_t low = 0;
      if (i + 2 >= input.size() || !HexDigit(input[i + 1], high) || !HexDigit(input[i + 2], low)) {
        return false;
      }
      output.push_back(static_cast<char>((high << 4) | low));
      i += 2;
    }
  }
  return true;
}

int ParsePartitionValuesFromPath(
    const paimon::TableSchema &schema,
    const std::string &file_path,
    std::vector<PartitionValue> &values)
{
  int ret = OB_EXT_SUCCESS;
  values.clear();
  const auto &partition_keys = schema.PartitionKeys();
  if (partition_keys.empty()) {
    return ret;
  }

  const auto &schema_options = schema.Options();
  const auto default_name_iter = schema_options.find(paimon::Options::PARTITION_DEFAULT_NAME);
  const std::string default_partition_name = default_name_iter == schema_options.end()
      ? "__DEFAULT_PARTITION__"
      : default_name_iter->second;
  const size_t file_name_separator = file_path.rfind('/');
  if (file_name_separator == std::string::npos) {
    ret = OB_EXT_INVALID_DATA;
  }

  std::map<std::string, std::string> path_values;
  for (size_t start = 0; ret == OB_EXT_SUCCESS && start < file_name_separator;) {
    const size_t end = file_path.find('/', start);
    const size_t segment_end =
        end == std::string::npos || end > file_name_separator ? file_name_separator : end;
    if (segment_end > start) {
      const std::string segment = file_path.substr(start, segment_end - start);
      const size_t equal = segment.find('=');
      if (equal != std::string::npos) {
        std::string key;
        if (!PercentDecode(segment.substr(0, equal), key)) {
          ret = OB_EXT_INVALID_DATA;
        } else if (
            std::find(partition_keys.begin(), partition_keys.end(), key) != partition_keys.end()) {
          std::string value;
          if (equal == 0 || equal + 1 == segment.size()
              || !PercentDecode(segment.substr(equal + 1), value) || value.empty()
              || !path_values.emplace(key, std::move(value)).second) {
            ret = OB_EXT_INVALID_DATA;
          }
        }
      }
    }
    if (segment_end == file_name_separator) {
      break;
    }
    start = segment_end + 1;
  }

  values.reserve(partition_keys.size());
  for (auto key_iter = partition_keys.begin();
       ret == OB_EXT_SUCCESS && key_iter != partition_keys.end();
       ++key_iter) {
    const auto &key = *key_iter;
    const auto path_value = path_values.find(key);
    auto field = schema.GetField(key);
    if (path_value == path_values.end() || !field.ok()) {
      ret = OB_EXT_INVALID_DATA;
    } else {
      PartitionValue partition_value;
      partition_value.field_id = field.value().Id();
      if (path_value->second != default_partition_name) {
        partition_value.value = path_value->second;
      }
      values.emplace_back(std::move(partition_value));
    }
  }
  if (ret != OB_EXT_SUCCESS) {
    values.clear();
  }
  return ret;
}

bool PartitionValuesEqual(
    const std::vector<PartitionValue> &left,
    const std::vector<PartitionValue> &right)
{
  if (left.size() != right.size()) {
    return false;
  }
  for (size_t i = 0; i < left.size(); ++i) {
    if (left[i].field_id != right[i].field_id
        || left[i].value.has_value() != right[i].value.has_value()
        || (left[i].value.has_value() && left[i].value.value() != right[i].value.value())) {
      return false;
    }
  }
  return true;
}

int BuildTaskPartitionValues(
    const std::shared_ptr<paimon::Split> &split,
    const paimon::TableSchema &schema,
    std::vector<PartitionValue> &values)
{
  int ret = OB_EXT_SUCCESS;
  values.clear();
  if (!schema.PartitionKeys().empty()) {
    std::shared_ptr<paimon::DataSplit> data_split =
        std::dynamic_pointer_cast<paimon::DataSplit>(split);
    const auto indexed_split = std::dynamic_pointer_cast<paimon::IndexedSplit>(split);
    if (data_split == nullptr && indexed_split != nullptr) {
      data_split = indexed_split->GetDataSplit();
    }
    if (data_split == nullptr || data_split->GetFileList().empty()) {
      ret = OB_EXT_INVALID_DATA;
    } else {
      const auto file_list = data_split->GetFileList();
      ret = ParsePartitionValuesFromPath(schema, file_list.front().file_path, values);
      for (size_t i = 1; ret == OB_EXT_SUCCESS && i < file_list.size(); ++i) {
        std::vector<PartitionValue> file_values;
        ret = ParsePartitionValuesFromPath(schema, file_list[i].file_path, file_values);
        if (ret == OB_EXT_SUCCESS && !PartitionValuesEqual(values, file_values)) {
          ret = OB_EXT_INVALID_DATA;
        }
      }
    }
  }
  if (ret != OB_EXT_SUCCESS) {
    values.clear();
  }
  return ret;
}

void AppendPartitionValuesJson(
    const std::vector<PartitionValue> &values,
    rapidjson::Value &task,
    rapidjson::Document::AllocatorType &allocator)
{
  rapidjson::Value partition_values(rapidjson::kArrayType);
  for (const auto &partition : values) {
    rapidjson::Value entry(rapidjson::kObjectType);
    entry.AddMember(rapidjson::StringRef(OB_EXT_K_FIELD_ID), partition.field_id, allocator);
    rapidjson::Value value(rapidjson::kNullType);
    if (partition.value.has_value()) {
      value.SetString(
          partition.value->c_str(),
          static_cast<rapidjson::SizeType>(partition.value->size()),
          allocator);
    }
    entry.AddMember(rapidjson::StringRef(OB_EXT_K_VALUE), value, allocator);
    partition_values.PushBack(entry, allocator);
  }
  task.AddMember(rapidjson::StringRef(OB_EXT_K_PARTITION_VALUES), partition_values, allocator);
}

bool BuildObFileScanDescriptor(
    const std::shared_ptr<paimon::Split> &split,
    const paimon::TableSchema &schema,
    ObFileScanDescriptor &descriptor,
    const char *&fallback_reason)
{
  fallback_reason = nullptr;
  if (std::dynamic_pointer_cast<paimon::IndexedSplit>(split) != nullptr) {
    fallback_reason = "indexed_split";
    return false;
  }

  const auto data_split = std::dynamic_pointer_cast<paimon::DataSplit>(split);
  if (data_split == nullptr) {
    fallback_reason = "not_data_split";
    return false;
  }
  // RawConvertible() is determiend internally by Paimon itself, it means the data split does not
  // need to be read by merge reader.
  if (!data_split->RawConvertible()) {
    fallback_reason = "not_raw_convertible";
    return false;
  }
  const auto file_list = data_split->GetFileList();
  if (file_list.empty()) {
    fallback_reason = "empty_file_list";
    return false;
  }

  descriptor.files.reserve(file_list.size());
  for (const auto &file_meta : file_list) {
    if (file_meta.file_path.empty() || file_meta.file_size < 0 || file_meta.row_count < 0) {
      fallback_reason = "invalid_file_metadata";
      return false;
    }
    if (file_meta.schema_id != schema.Id()) {
      fallback_reason = "file_schema_mismatch";
      return false;
    }
    // OB file scan does not support delete rows.
    if (file_meta.delete_row_count.has_value() && file_meta.delete_row_count.value() != 0) {
      fallback_reason = "delete_rows";
      return false;
    }

    std::string file_format;
    if (!DetectObFileFormat(file_meta.file_path, file_format)) {
      fallback_reason = "unknown_file_format";
      return false;
    }
    if (descriptor.file_format.empty()) {
      descriptor.file_format = std::move(file_format);
    } else if (descriptor.file_format != file_format) {
      fallback_reason = "mixed_file_format";
      return false;
    }
    descriptor.files.push_back({file_meta.file_path, file_meta.file_size, file_meta.row_count});
  }
  return true;
}

int AppendTaskPartitionValues(
    const std::shared_ptr<paimon::Split> &split,
    const paimon::TableSchema &schema,
    rapidjson::Value &task,
    rapidjson::Document::AllocatorType &allocator)
{
  std::vector<PartitionValue> values;
  const int ret = BuildTaskPartitionValues(split, schema, values);
  if (ret == OB_EXT_SUCCESS) {
    AppendPartitionValuesJson(values, task, allocator);
  }
  return ret;
}

bool AppendObFileScanDescriptors(
    const std::vector<std::shared_ptr<paimon::Split>> &splits,
    const std::shared_ptr<paimon::TableSchema> &schema,
    const std::map<std::string, std::string> &option_overrides,
    rapidjson::Value &tasks,
    rapidjson::Document::AllocatorType &allocator,
    const char *&fallback_reason)
{
  fallback_reason = nullptr;
  if (schema == nullptr) {
    fallback_reason = "missing_pinned_schema";
    return false;
  }
  auto effective_options = schema->Options();
  for (const auto &[key, value] : option_overrides) {
    effective_options[key] = value;
  }
  if (!schema->PrimaryKeys().empty()) {
    fallback_reason = "primary_key_table";
    return false;
  }
  if (!IsOptionDisabled(effective_options, paimon::Options::DATA_EVOLUTION_ENABLED)) {
    fallback_reason = "data_evolution_table";
    return false;
  }
  if (!IsOptionDisabled(effective_options, paimon::Options::DELETION_VECTORS_ENABLED)) {
    fallback_reason = "deletion_vectors_enabled";
    return false;
  }
  if (splits.empty() || tasks.Size() != static_cast<rapidjson::SizeType>(splits.size())) {
    fallback_reason = "empty_plan";
    return false;
  }

  std::vector<ObFileScanDescriptor> descriptors;
  descriptors.reserve(splits.size());
  std::string plan_file_format;
  for (const auto &split : splits) {
    ObFileScanDescriptor descriptor;
    const char *split_reason = nullptr;
    if (!BuildObFileScanDescriptor(split, *schema, descriptor, split_reason)) {
      fallback_reason = split_reason;
      return false;
    }
    if (plan_file_format.empty()) {
      plan_file_format = descriptor.file_format;
    } else if (plan_file_format != descriptor.file_format) {
      fallback_reason = "mixed_file_format";
      return false;
    }
    descriptors.emplace_back(std::move(descriptor));
  }

  for (size_t i = 0; i < descriptors.size(); ++i) {
    const auto &descriptor = descriptors[i];
    rapidjson::Value ob_file_scan(rapidjson::kObjectType);
    ob_file_scan.AddMember(
        rapidjson::StringRef(OB_EXT_K_OB_FILE_SCAN_VERSION), 1, allocator);
    ob_file_scan.AddMember(
        rapidjson::StringRef(OB_EXT_K_OB_FILE_SCAN_FORMAT),
        rapidjson::Value(
            descriptor.file_format.c_str(),
            static_cast<rapidjson::SizeType>(descriptor.file_format.size()),
            allocator),
        allocator);

    rapidjson::Value files(rapidjson::kArrayType);
    for (const auto &file : descriptor.files) {
      rapidjson::Value file_value(rapidjson::kObjectType);
      file_value.AddMember(
          rapidjson::StringRef(OB_EXT_K_OB_FILE_SCAN_PATH),
          rapidjson::Value(
              file.file_path.c_str(),
              static_cast<rapidjson::SizeType>(file.file_path.size()),
              allocator),
          allocator);
      file_value.AddMember(
          rapidjson::StringRef(OB_EXT_K_OB_FILE_SCAN_BYTE_SIZE), file.byte_size, allocator);
      file_value.AddMember(
          rapidjson::StringRef(OB_EXT_K_ROW_COUNT), file.row_count_, allocator);
      files.PushBack(file_value, allocator);
    }
    ob_file_scan.AddMember(rapidjson::StringRef(OB_EXT_K_FILES), files, allocator);
    tasks[static_cast<rapidjson::SizeType>(i)].AddMember(
        rapidjson::StringRef(OB_EXT_K_OB_FILE_SCAN),
        ob_file_scan,
        allocator);
  }
  return true;
}

}  // namespace

int ScanTaskProducer::Produce(
    const std::shared_ptr<paimon::Plan> &plan,
    const std::shared_ptr<paimon::MemoryPool> &pool,
    const std::shared_ptr<paimon::TableSchema> &schema,
    const std::map<std::string, std::string> &option_overrides,
    bool partition_filter_applied,
    const ObExtTableHostApi *host,
    std::string &tasks_json)
{
  int ret = OB_EXT_SUCCESS;
  tasks_json.clear();
  rapidjson::Document doc;
  doc.SetObject();
  rapidjson::Document::AllocatorType &allocator = doc.GetAllocator();
  rapidjson::Value tasks(rapidjson::kArrayType);
  const auto &splits = plan->Splits();
  if (!splits.empty() && schema == nullptr) {
    ret = OB_EXT_INVALID_DATA;
  }
  for (auto iter = splits.begin(); ret == OB_EXT_SUCCESS && iter != splits.end(); ++iter) {
    const auto &split = *iter;
    auto bytes_result = paimon::Split::Serialize(split, pool);
    if (!bytes_result.ok()) {
      OBEXT_LOG_WARN(
          host, "plan_create: Split::Serialize: %s", bytes_result.status().ToString().c_str());
      ret = status_to_errno(bytes_result.status());
    } else {
      const std::string serialized_split = std::move(bytes_result).value();
      const std::string plugin_split = Base64Encode(
          serialized_split.data(), static_cast<int32_t>(serialized_split.size()));

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
        for (const auto &file_meta : data_split->GetFileList()) {
          row_count += file_meta.row_count;
          byte_size += file_meta.file_size;
        }
      }
      task.AddMember(rapidjson::StringRef(OB_EXT_K_ROW_COUNT), row_count, allocator);
      task.AddMember(rapidjson::StringRef(OB_EXT_K_BYTE_SIZE), byte_size, allocator);
      task.AddMember(
          rapidjson::StringRef(OB_EXT_K_FILES),
          rapidjson::Value(rapidjson::kArrayType),
          allocator);
      task.AddMember(rapidjson::StringRef(OB_EXT_K_SPLITTABLE), false, allocator);
      task.AddMember(
          rapidjson::StringRef(OB_EXT_K_PLUGIN_SPLIT),
          rapidjson::Value(
              plugin_split.c_str(),
              static_cast<rapidjson::SizeType>(plugin_split.size()),
              allocator),
          allocator);
      if (OB_EXT_SUCCESS !=
          (ret = AppendTaskPartitionValues(split, *schema, task, allocator))) {
        OBEXT_LOG_WARN(host, "plan_create: invalid task partition values");
      } else {
        tasks.PushBack(task, allocator);
      }
    }
  }
  if (ret == OB_EXT_SUCCESS) {
    const char *ob_file_scan_fallback_reason = nullptr;
    if (!AppendObFileScanDescriptors(
            splits,
            schema,
            option_overrides,
            tasks,
            allocator,
            ob_file_scan_fallback_reason)) {
      OBEXT_LOG_TRACE(
          host,
          "plan_create: OB file scan unavailable: %s",
          ob_file_scan_fallback_reason == nullptr ? "unknown" : ob_file_scan_fallback_reason);
    }
    doc.AddMember(
        rapidjson::StringRef(OB_EXT_K_PARTITION_FILTER_APPLIED),
        partition_filter_applied,
        allocator);
    doc.AddMember(rapidjson::StringRef(OB_EXT_K_TASKS), tasks, allocator);
    rapidjson::StringBuffer buffer;
    rapidjson::Writer<rapidjson::StringBuffer> writer(buffer);
    doc.Accept(writer);
    tasks_json.assign(buffer.GetString(), buffer.GetSize());
  }
  return ret;
}

}  // namespace ob_ext_paimon
