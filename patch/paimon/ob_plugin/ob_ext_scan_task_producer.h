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

#pragma once

#include <map>
#include <memory>
#include <string>

namespace paimon
{
class MemoryPool;
class Plan;
class TableSchema;
}  // namespace paimon

struct ObExtTableHostApi;

namespace ob_ext_paimon
{

// Paimon Plan::Splits
//          |
//          v
// ScanTaskProducer::Produce
//          |
//          v
// root task: plugin_split + partition_values + optional ob_file_scan
//          |
//          v
// OB pruner / PX distribution / AccessService
//          |                           |
//          | plugin_split              | ob_file_scan
//          v                           v
// ObPluginScanTask               ob_file_scan.files expanded
//          |                           |
//          v                           v
// plugin reader                  OB Parquet / ORC reader
class ScanTaskProducer
{
public:
  ScanTaskProducer() = delete;

  // Serialize one plan into the generic task envelope returned by plan_create.
  // An empty plan is valid even when no snapshot schema exists.
  static int Produce(
      const std::shared_ptr<paimon::Plan> &plan,
      const std::shared_ptr<paimon::MemoryPool> &pool,
      const std::shared_ptr<paimon::TableSchema> &schema,
      const std::map<std::string, std::string> &option_overrides,
      bool partition_filter_applied,
      const ObExtTableHostApi *host,
      std::string &tasks_json);
};

}  // namespace ob_ext_paimon
