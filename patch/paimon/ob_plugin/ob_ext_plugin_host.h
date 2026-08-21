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

/// \file ob_ext_plugin_host.h
/// \brief Adapt OB's generic external-table host API into paimon C++ interfaces.
///
/// Also defines `OBEXT_LOG_*` — the paimon plugin's only logging path. The host
/// hands the plugin a `log` callback (see `ob_ext_log_level` in
/// ob_external_table_plugin.h); these macros snprintf the message and route it
/// through `host->log(...)` so plugin diagnostics land in OB's observer.log
/// under module "[ExtPlugin]" instead of stdout/stderr. Safe to call with a null
/// host or missing `log` slot (no-op).

#pragma once

#include "paimon/ob_external_table_plugin.h"

#include <cstdarg>
#include <cstdio>
#include <memory>

namespace paimon {
class Executor;
class FileSystem;
class MemoryPool;
}  // namespace paimon

namespace ob_ext_paimon {

std::shared_ptr<paimon::MemoryPool> make_memory_pool(const ObExtTableHostApi* host);
std::shared_ptr<paimon::Executor> make_executor(const ObExtTableHostApi* host);
std::shared_ptr<paimon::FileSystem> make_file_system(
    const ObExtTableHostApi* host, std::shared_ptr<paimon::Executor> executor);

// ---- logging ----
// Format the message into a stack buffer and hand it to the host's `log`
// callback. No-op when host / host->log is absent (e.g. host built before the
// log slot existed). Truncates at kObExtLogBufLen to keep the call cheap.
inline constexpr int kObExtLogBufLen = 1024;
inline void obext_log(const ObExtTableHostApi* host, int32_t level, const char* file,
                      int32_t line, const char* func, const char* fmt, ...)
    __attribute__((format(printf, 6, 7)));
inline void obext_log(const ObExtTableHostApi* host, int32_t level, const char* file,
                      int32_t line, const char* func, const char* fmt, ...)
{
  if (host == nullptr || host->log == nullptr) {
    return;
  }
  char buf[kObExtLogBufLen];
  va_list args;
  va_start(args, fmt);
  std::vsnprintf(buf, sizeof(buf), fmt, args);
  va_end(args);
  host->log(host->ctx, level, file, line, func, buf);
}

}  // namespace ob_ext_paimon

// Usage: OBEXT_LOG_WARN(host, "load_schema failed: %s", uri). `host` is the
// `const ObExtTableHostApi*` in scope; pass nullptr-safe (the helper no-ops).
// These are macros (not a function template) so __FILE__/__LINE__/__func__ capture
// the real call site, and so the format-string checker sees a literal format.
#define OBEXT_LOG_TRACE(host, fmt, ...) \
  ::ob_ext_paimon::obext_log((host), OB_EXT_LOG_TRACE, __FILE__, __LINE__, __func__, (fmt), ##__VA_ARGS__)
#define OBEXT_LOG_INFO(host, fmt, ...)  \
  ::ob_ext_paimon::obext_log((host), OB_EXT_LOG_INFO,  __FILE__, __LINE__, __func__, (fmt), ##__VA_ARGS__)
#define OBEXT_LOG_WARN(host, fmt, ...)  \
  ::ob_ext_paimon::obext_log((host), OB_EXT_LOG_WARN,  __FILE__, __LINE__, __func__, (fmt), ##__VA_ARGS__)
#define OBEXT_LOG_ERROR(host, fmt, ...) \
  ::ob_ext_paimon::obext_log((host), OB_EXT_LOG_ERROR, __FILE__, __LINE__, __func__, (fmt), ##__VA_ARGS__)

// _AT variants: log with an EXPLICIT call site (file/line/func) instead of the
// current line. Used by helpers invoked from many sites (e.g. fail_exception)
// so observer.log points at the caller's catch block, not inside the helper.
#define OBEXT_LOG_WARN_AT(host, file, line, func, fmt, ...) \
  ::ob_ext_paimon::obext_log((host), OB_EXT_LOG_WARN, (file), (line), (func), (fmt), ##__VA_ARGS__)

