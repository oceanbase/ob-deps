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

#include "ob_ext_plugin_logger.h"

#include "ob_ext_plugin_host.h"  // kObExtLogBufLen (shared buffer size)

#include <atomic>
#include <cstdio>
#include <mutex>
#include <vector>

namespace ob_ext_paimon {

namespace {

// Per-thread host stack. Plain vector of raw pointers — the hosts are
// OB-owned and outlive every plugin call on their thread, so no refcounting.
thread_local std::vector<const ObExtTableHostApi*> g_host_stack;

// Map paimon's log level onto OB's. DEBUG collapses to TRACE (the most
// verbose OB level); NONE is never actually logged (paimon filters it before
// calling LogV). Falls back to WARN for anything unexpected so a mis-mapped
// level is at least visible rather than dropped.
int32_t to_obext_level(paimon::PaimonLogLevel level)
{
  switch (level) {
    case paimon::PAIMON_LOG_LEVEL_DEBUG:
      return OB_EXT_LOG_TRACE;
    case paimon::PAIMON_LOG_LEVEL_INFO:
      return OB_EXT_LOG_INFO;
    case paimon::PAIMON_LOG_LEVEL_WARN:
      return OB_EXT_LOG_WARN;
    case paimon::PAIMON_LOG_LEVEL_ERROR:
      return OB_EXT_LOG_ERROR;
    case paimon::PAIMON_LOG_LEVEL_NONE:
    case paimon::PAIMON_LOG_LEVEL_MAX:
    default:
      return OB_EXT_LOG_WARN;
  }
}

class ObExtBridgeLogger final : public paimon::Logger {
 public:
  void LogV(paimon::PaimonLogLevel level, const char* fname, int lineno,
            const char* function, const char* fmt, ...) override
  {
    // Always format first: paimon logs are rare enough on the hot path that the
    // snprintf cost is negligible, and formatting before the host check means a
    // missing host still gets the line on stderr (no silent drop).
    char buf[kObExtLogBufLen];
    va_list args;
    va_start(args, fmt);
    int n = std::vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);
    if (n < 0) {
      return;
    }
    const int32_t ob_level = to_obext_level(level);
    const ObExtTableHostApi* host = CurrentHost::current();
    if (host != nullptr && host->log != nullptr) {
      // Tag the message so OB's log distinguishes paimon-SDK internals from
      // the plugin's own OBEXT_LOG_* output (same [ExtPlugin] module).
      host->log(host->ctx, ob_level, fname, lineno, function, buf);
      return;
    }
    // No host on this thread (paimon logging outside any plugin call, e.g.
    // static destructors or a background executor thread). Degrade to stderr
    // so the line is not lost; prefixed "[paimon]" for greppability.
    std::fprintf(stderr, "[paimon] %s:%d %s: %s\n",
                 fname != nullptr ? fname : "", lineno,
                 function != nullptr ? function : "", buf);
  }

  // Host filtering (OB_LOGGER.need_to_print) happens inside the host's log
  // callback, so we can't cheaply pre-filter here. Return true to let paimon
  // always format + forward; the host drops what its level doesn't want. This
  // trades a snprintf per paimon log line for not silently losing diagnostics.
  bool IsLevelEnabled(paimon::PaimonLogLevel /*level*/) const override { return true; }
};

}  // namespace

CurrentHost::Scope::Scope(const ObExtTableHostApi* host) { g_host_stack.push_back(host); }
CurrentHost::Scope::~Scope()
{
  if (!g_host_stack.empty()) {
    g_host_stack.pop_back();
  }
}

const ObExtTableHostApi* CurrentHost::current()
{
  return g_host_stack.empty() ? nullptr : g_host_stack.back();
}

void register_paimon_logger_bridge()
{
  static std::once_flag flag;
  std::call_once(flag, []() {
    paimon::Logger::RegisterLogger(
        [](const std::string&) -> std::unique_ptr<paimon::Logger> {
          return std::make_unique<ObExtBridgeLogger>();
        });
  });
}

}  // namespace ob_ext_paimon
