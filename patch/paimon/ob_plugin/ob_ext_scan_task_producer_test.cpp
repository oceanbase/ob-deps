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

#include <memory>
#include <optional>
#include <string>
#include <utility>
#include <vector>

#include <arrow/api.h>
#include <gtest/gtest.h>
#include <rapidjson/document.h>

#include "paimon/common/data/binary_row.h"
#include "paimon/core/io/data_file_meta.h"
#include "paimon/core/manifest/file_source.h"
#include "paimon/core/schema/table_schema.h"
#include "paimon/core/stats/simple_stats.h"
#include "paimon/core/table/source/data_split_impl.h"
#include "paimon/core/table/source/plan_impl.h"
#include "paimon/memory/memory_pool.h"
#include "paimon/ob_external_table_plugin.h"

namespace ob_ext_paimon
{
namespace
{

TEST(ObExtScanTaskProducerTest, EmptyPlanWithoutSnapshotSchema)
{
  ObExtTableHostApi host = {};
  std::string tasks_json;

  ASSERT_EQ(OB_EXT_SUCCESS,
            ScanTaskProducer::Produce(
                paimon::PlanImpl::EmptyPlan(), paimon::GetDefaultPool(), nullptr, {}, false,
                &host, tasks_json));
  rapidjson::Document result;
  result.Parse(tasks_json.data(), tasks_json.size());
  ASSERT_FALSE(result.HasParseError());
  ASSERT_TRUE(result.HasMember(OB_EXT_K_TASKS));
  EXPECT_TRUE(result[OB_EXT_K_TASKS].IsArray());
  EXPECT_TRUE(result[OB_EXT_K_TASKS].Empty());
}

TEST(ObExtScanTaskProducerTest, EmitsPartitionTupleAndMultiFileObFileScan)
{
  auto schema_result = paimon::TableSchema::Create(
      0, arrow::schema({arrow::field("dt", arrow::utf8()),
                        arrow::field("region", arrow::utf8())}),
      {"dt", "region"}, {}, {});
  ASSERT_TRUE(schema_result.ok()) << schema_result.status().ToString();
  std::shared_ptr<paimon::TableSchema> schema(std::move(schema_result).value());
  auto first_file_result = paimon::DataFileMeta::ForAppend(
      "a.parquet", 10, 3, paimon::SimpleStats::EmptyStats(), 0, 0, 0,
      paimon::FileSource::Append(), std::nullopt, std::nullopt, std::nullopt, std::nullopt);
  ASSERT_TRUE(first_file_result.ok()) << first_file_result.status().ToString();
  auto second_file_result = paimon::DataFileMeta::ForAppend(
      "b.parquet", 20, 4, paimon::SimpleStats::EmptyStats(), 0, 0, 0,
      paimon::FileSource::Append(), std::nullopt, std::nullopt, std::nullopt, std::nullopt);
  ASSERT_TRUE(second_file_result.ok()) << second_file_result.status().ToString();
  paimon::DataSplitImpl::Builder split_builder(
      paimon::BinaryRow::EmptyRow(),
      0,
      "oss://bucket/table/dt=2025%2F01/region=__DEFAULT_PARTITION__/bucket-0",
      {std::move(first_file_result).value(), std::move(second_file_result).value()});
  auto split_result = split_builder.RawConvertible(true).Build();
  ASSERT_TRUE(split_result.ok()) << split_result.status().ToString();
  std::shared_ptr<paimon::DataSplit> data_split = std::move(split_result).value();
  ASSERT_TRUE(data_split->RawConvertible());
  std::shared_ptr<paimon::Split> split = data_split;
  std::shared_ptr<paimon::Plan> plan = std::make_shared<paimon::PlanImpl>(
      std::optional<int64_t>(0), std::vector<std::shared_ptr<paimon::Split>>{split});

  ObExtTableHostApi host = {};
  std::string tasks_json;
  ASSERT_EQ(
      OB_EXT_SUCCESS,
      ScanTaskProducer::Produce(
          plan, paimon::GetDefaultPool(), schema, {}, false, &host, tasks_json));

  rapidjson::Document result;
  result.Parse(tasks_json.data(), tasks_json.size());
  ASSERT_FALSE(result.HasParseError());
  ASSERT_TRUE(result.HasMember(OB_EXT_K_TASKS));
  EXPECT_FALSE(result[OB_EXT_K_PARTITION_FILTER_APPLIED].GetBool());
  const rapidjson::Value &tasks = result[OB_EXT_K_TASKS];
  ASSERT_EQ(1U, tasks.Size());
  EXPECT_EQ(7, tasks[0][OB_EXT_K_ROW_COUNT].GetInt64());
  EXPECT_EQ(30, tasks[0][OB_EXT_K_BYTE_SIZE].GetInt64());
  EXPECT_GT(tasks[0][OB_EXT_K_PLUGIN_SPLIT].GetStringLength(), 0U);

  const rapidjson::Value &partition_values = tasks[0][OB_EXT_K_PARTITION_VALUES];
  ASSERT_EQ(2U, partition_values.Size());
  EXPECT_EQ(schema->GetField("dt").value().Id(),
            partition_values[0][OB_EXT_K_FIELD_ID].GetInt());
  EXPECT_STREQ("2025/01", partition_values[0][OB_EXT_K_VALUE].GetString());
  EXPECT_TRUE(partition_values[1][OB_EXT_K_VALUE].IsNull());
  const rapidjson::Value &ob_file_scan = tasks[0][OB_EXT_K_OB_FILE_SCAN];
  EXPECT_EQ(1, ob_file_scan[OB_EXT_K_OB_FILE_SCAN_VERSION].GetInt());
  EXPECT_STREQ("parquet", ob_file_scan[OB_EXT_K_OB_FILE_SCAN_FORMAT].GetString());
  const rapidjson::Value &ob_files = ob_file_scan[OB_EXT_K_FILES];
  ASSERT_EQ(2U, ob_files.Size());
  EXPECT_EQ(3, ob_files[0][OB_EXT_K_ROW_COUNT].GetInt64());
  EXPECT_EQ(4, ob_files[1][OB_EXT_K_ROW_COUNT].GetInt64());
}

TEST(ObExtScanTaskProducerTest, DeleteRowsKeepPluginTask)
{
  auto schema_result = paimon::TableSchema::Create(
      0, arrow::schema({arrow::field("id", arrow::int64())}), {}, {}, {});
  ASSERT_TRUE(schema_result.ok()) << schema_result.status().ToString();
  std::shared_ptr<paimon::TableSchema> schema(std::move(schema_result).value());
  auto file_result = paimon::DataFileMeta::ForAppend(
      "a.parquet", 10, 3, paimon::SimpleStats::EmptyStats(), 0, 0, 0,
      paimon::FileSource::Append(), std::nullopt, std::nullopt, std::nullopt, std::nullopt);
  ASSERT_TRUE(file_result.ok()) << file_result.status().ToString();
  auto file = std::move(file_result).value();
  file->delete_row_count = 1;
  paimon::DataSplitImpl::Builder split_builder(
      paimon::BinaryRow::EmptyRow(), 0, "oss://bucket/table/bucket-0", {file});
  auto split_result = split_builder.RawConvertible(true).Build();
  ASSERT_TRUE(split_result.ok()) << split_result.status().ToString();
  std::shared_ptr<paimon::Split> split = std::move(split_result).value();
  std::shared_ptr<paimon::Plan> plan = std::make_shared<paimon::PlanImpl>(
      std::optional<int64_t>(0), std::vector<std::shared_ptr<paimon::Split>>{split});

  ObExtTableHostApi host = {};
  std::string tasks_json;
  ASSERT_EQ(OB_EXT_SUCCESS,
            ScanTaskProducer::Produce(
                plan, paimon::GetDefaultPool(), schema, {}, false, &host, tasks_json));
  rapidjson::Document result;
  result.Parse(tasks_json.data(), tasks_json.size());
  ASSERT_FALSE(result.HasParseError());
  const rapidjson::Value &tasks = result[OB_EXT_K_TASKS];
  ASSERT_EQ(1U, tasks.Size());
  EXPECT_TRUE(tasks[0].HasMember(OB_EXT_K_PLUGIN_SPLIT));
  EXPECT_FALSE(tasks[0].HasMember(OB_EXT_K_OB_FILE_SCAN));
}

TEST(ObExtScanTaskProducerTest, NonRawConvertibleSplitKeepsPluginTask)
{
  auto schema_result = paimon::TableSchema::Create(
      0, arrow::schema({arrow::field("id", arrow::int64())}), {}, {}, {});
  ASSERT_TRUE(schema_result.ok()) << schema_result.status().ToString();
  std::shared_ptr<paimon::TableSchema> schema(std::move(schema_result).value());
  auto file_result = paimon::DataFileMeta::ForAppend(
      "a.parquet", 10, 3, paimon::SimpleStats::EmptyStats(), 0, 0, 0,
      paimon::FileSource::Append(), std::nullopt, std::nullopt, std::nullopt, std::nullopt);
  ASSERT_TRUE(file_result.ok()) << file_result.status().ToString();
  paimon::DataSplitImpl::Builder split_builder(
      paimon::BinaryRow::EmptyRow(), 0, "oss://bucket/table/bucket-0",
      {std::move(file_result).value()});
  auto split_result = split_builder.RawConvertible(false).Build();
  ASSERT_TRUE(split_result.ok()) << split_result.status().ToString();
  std::shared_ptr<paimon::Split> split = std::move(split_result).value();
  std::shared_ptr<paimon::Plan> plan = std::make_shared<paimon::PlanImpl>(
      std::optional<int64_t>(0), std::vector<std::shared_ptr<paimon::Split>>{split});

  ObExtTableHostApi host = {};
  std::string tasks_json;
  ASSERT_EQ(OB_EXT_SUCCESS,
            ScanTaskProducer::Produce(
                plan, paimon::GetDefaultPool(), schema, {}, false, &host, tasks_json));
  rapidjson::Document result;
  result.Parse(tasks_json.data(), tasks_json.size());
  ASSERT_FALSE(result.HasParseError());
  const rapidjson::Value &tasks = result[OB_EXT_K_TASKS];
  ASSERT_EQ(1U, tasks.Size());
  EXPECT_TRUE(tasks[0].HasMember(OB_EXT_K_PLUGIN_SPLIT));
  EXPECT_FALSE(tasks[0].HasMember(OB_EXT_K_OB_FILE_SCAN));
}

TEST(ObExtScanTaskProducerTest, UnknownFileRowCountKeepsPluginTask)
{
  auto schema_result = paimon::TableSchema::Create(
      0, arrow::schema({arrow::field("id", arrow::int64())}), {}, {}, {});
  ASSERT_TRUE(schema_result.ok()) << schema_result.status().ToString();
  std::shared_ptr<paimon::TableSchema> schema(std::move(schema_result).value());
  auto file_result = paimon::DataFileMeta::ForAppend(
      "a.parquet", 10, 3, paimon::SimpleStats::EmptyStats(), 0, 0, 0,
      paimon::FileSource::Append(), std::nullopt, std::nullopt, std::nullopt, std::nullopt);
  ASSERT_TRUE(file_result.ok()) << file_result.status().ToString();
  auto file = std::move(file_result).value();
  file->row_count = -1;
  paimon::DataSplitImpl::Builder split_builder(
      paimon::BinaryRow::EmptyRow(), 0, "oss://bucket/table/bucket-0", {file});
  auto split_result = split_builder.RawConvertible(true).Build();
  ASSERT_TRUE(split_result.ok()) << split_result.status().ToString();
  std::shared_ptr<paimon::Split> split = std::move(split_result).value();
  std::shared_ptr<paimon::Plan> plan = std::make_shared<paimon::PlanImpl>(
      std::optional<int64_t>(0), std::vector<std::shared_ptr<paimon::Split>>{split});

  ObExtTableHostApi host = {};
  std::string tasks_json;
  ASSERT_EQ(OB_EXT_SUCCESS,
            ScanTaskProducer::Produce(
                plan, paimon::GetDefaultPool(), schema, {}, false, &host, tasks_json));
  rapidjson::Document result;
  result.Parse(tasks_json.data(), tasks_json.size());
  ASSERT_FALSE(result.HasParseError());
  const rapidjson::Value &tasks = result[OB_EXT_K_TASKS];
  ASSERT_EQ(1U, tasks.Size());
  EXPECT_TRUE(tasks[0].HasMember(OB_EXT_K_PLUGIN_SPLIT));
  EXPECT_FALSE(tasks[0].HasMember(OB_EXT_K_OB_FILE_SCAN));
}

}  // namespace
}  // namespace ob_ext_paimon
