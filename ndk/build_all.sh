#!/bin/bash
#
# build_all.sh -- Build all Android arm64-v8a dependencies in order
#
# Usage:
#   bash ndk/build_all.sh
#
# Each dep is built and packaged as .tar.gz in ndk/output/.
#

set -e

NDK_DIR=$(cd "$(dirname "$0")" && pwd)

echo "======================================"
echo "  Android NDK Dependency Build"
echo "======================================"
echo ""

run_build() {
    local script=$1
    local name=$(basename "$script" .sh)
    echo ""
    echo "######################################"
    echo "# $name"
    echo "######################################"
    bash "$NDK_DIR/$script"
}

# ============================================================
# Phase 1: No inter-dependencies
# ============================================================

run_build devdeps-fast-float-build.sh
run_build devdeps-relaxed-rapidjson-build.sh
run_build devdeps-zlib-build.sh
run_build devdeps-xz-build.sh
run_build devdeps-openssl-build.sh
run_build devdeps-icu-build.sh
run_build devdeps-abseil-cpp-build.sh
run_build devdeps-roaringbitmap-build.sh
run_build devdeps-protobuf-c-build.sh
run_build devdeps-mxml-build.sh
run_build devdeps-lua-build.sh
run_build devdeps-libxml2-build.sh
run_build devdeps-boost-build.sh

# ============================================================
# Phase 2: Depends on Phase 1
# ============================================================

run_build devdeps-libcurl-build.sh           # needs openssl
run_build devdeps-mariadb-connector-c-build.sh  # needs openssl, zlib
run_build devdeps-s2geometry-build.sh        # needs abseil-cpp

# ============================================================
# Phase 3: Complex, depends on Phase 1+2
# ============================================================

run_build devdeps-apache-arrow-build.sh      # needs zlib; builds own snappy/lz4/etc.
run_build devdeps-aws-sdk-build.sh           # needs openssl, libcurl, zlib

# ============================================================
# Phase 4: Depends on arrow
# ============================================================

run_build devdeps-apache-orc-build.sh        # needs zlib

# ============================================================
# Phase 5: Depends on roaringbitmap, boost
# ============================================================

run_build devdeps-vsag-build.sh              # needs roaring, boost headers

# ============================================================
# Summary
# ============================================================

echo ""
echo "======================================"
echo "  Build Complete!"
echo "======================================"
echo ""
echo "Tarballs in $NDK_DIR/output/:"
ls -la "$NDK_DIR/output/"*.tar.gz 2>/dev/null | while read line; do
    echo "  $line"
done
echo ""
echo "Total: $(ls "$NDK_DIR/output/"*.tar.gz 2>/dev/null | wc -l | tr -d ' ') tarballs"
