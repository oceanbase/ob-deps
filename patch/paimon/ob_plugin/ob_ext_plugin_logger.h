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

/// \file ob_ext_plugin_logger.h
/// \brief Bridge paimon SDK internal logs (`PAIMON_LOG_*`) into OB's logger via
/// the host `log` callback, so paimon-side diagnostics (parquet/orc reads,
/// split planning, schema parsing) land in observer.log under "[ExtPlugin]"
/// alongside the plugin's own `OBEXT_LOG_*` output.
///
/// ## Mechanism
/// `paimon::Logger::RegisterLogger` is a process-wide static slot. We register
/// `ObExtBridgeLogger` exactly once; thereafter every `paimon::Logger::GetLogger`
/// returns it, replacing glog's default `GlogAdaptor` (so glog is neither
/// initialized nor written to).
///
/// ## The host-lifetime mismatch
/// `RegisterLogger` is process-global, but the `host` (carrying `host->log`) is
/// scan-local: it arrives per plugin call and differs across tenants. So the
/// bridge logger cannot capture one host. Instead each plugin entry point
/// pushes the current call's host onto a thread-local stack via
/// `CurrentHostScope`; the bridge logger reads the top of that stack at log
/// time. Outside any plugin call the stack is empty and the bridge logger
/// falls back to stderr (so paimon logs from static destructors / background
/// threads are not silently dropped).

#pragma once

#include "paimon/ob_external_table_plugin.h"
#include "paimon/logging.h"

namespace ob_ext_paimon {

/// Thread-local stack of the hosts currently being served by plugin calls on
/// this thread. Pushed by every plugin entry point that receives a `host`;
/// read by `ObExtBridgeLogger::LogV`. A stack (not a single slot) makes nested
/// calls (e.g. reader_next_batch inside a host executor task that itself logs)
/// behave correctly.
class CurrentHost {
 public:
  /// RAII push/pop. Captures `host` (may be nullptr — still pushed so the
  /// depth is balanced and an inner nullptr doesn't mask an outer host).
  class Scope {
   public:
    explicit Scope(const ObExtTableHostApi* host);
    ~Scope();
    Scope(const Scope&) = delete;
    Scope& operator=(const Scope&) = delete;
  };

  /// Top of this thread's stack, or nullptr if no plugin call is active.
  static const ObExtTableHostApi* current();
};

/// Register `ObExtBridgeLogger` as paimon's process-wide logger. Safe to call
/// repeatedly; only the first call registers. Call once at plugin load
/// (from `ob_ext_table_plugin_get_api`, under `std::call_once`). After this
/// returns, paimon's glog default path is no longer used.
void register_paimon_logger_bridge();

}  // namespace ob_ext_paimon
