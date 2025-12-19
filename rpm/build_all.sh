#!/bin/bash
set -euo pipefail

# 统一的发行版本号（YYMMDD01）
RELEASE="$(date +'%y%m%d')01"

echo "=============================="
echo "开始批量构建所有依赖"
echo "RELEASE 版本号: ${RELEASE}"
echo "=============================="

# 所有要构建的项目脚本名（不带 .sh）
projects=(
  "obdevtools-llvm-17.0.6.sh"
  "obdevtools-bison-2.4.1.sh"
  "obdevtools-flex-2.5.35.sh"
  "devdeps-abseil-cpp-build.sh"
  "devdeps-apache-arrow-build.sh"
  "devdeps-apache-orc-build.sh"
  "devdeps-boost-build.sh"
  "devdeps-fast-float-build.sh"
  "devdeps-icu-build.sh"
  "devdeps-libcurl-build.sh"
  "devdeps-libxml2-build.sh"
  "devdeps-lua-build.sh"
  "devdeps-mariadb-connector-c-build.sh"
  "devdeps-mxml-build.sh"
  "devdeps-openssl-build.sh"
  "devdeps-protobuf-c-build.sh"
  "devdeps-relaxed-rapidjson-build.sh"
  "devdeps-roaringbitmap-croaring-build.sh"
  "devdeps-s2geometry-build.sh"
  "devdeps-s3-cpp-sdk-build.sh"
  "devdeps-xz-build.sh"
  "devdeps-zlib-build.sh"
)

# 循环构建
for script in "${projects[@]}"; do
  echo "------------------------------"
  echo "正在构建: ${script}"
  echo "------------------------------"

  bash "$script" "" "" "" "$RELEASE"

  echo "✅ ${script} 构建完成"
done

echo "=============================="
echo "全部 DevDeps 构建完成！"
echo "=============================="

