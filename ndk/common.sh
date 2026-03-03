#!/bin/bash
#
# common.sh -- shared environment for Android NDK dependency builds
#
# Source this file from each devdeps-*-build.sh script:
#   source "$(dirname "$0")/common.sh"
#
# Provides:
#   - NDK toolchain paths (CC, CXX, AR, RANLIB, STRIP)
#   - SOURCES_DIR pointing to git submodules
#   - PREFIX (shared install prefix for inter-dep discovery)
#   - OUTPUT_DIR for .tar.gz files
#   - package_dep() to create distributable tarballs
#

set -e

# Homebrew libtool installs as glibtoolize; autoreconf needs libtoolize on PATH
if [[ -d /opt/homebrew/opt/libtool/libexec/gnubin ]]; then
    export PATH="/opt/homebrew/opt/libtool/libexec/gnubin:$PATH"
fi

NDK_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OB_DEPS_DIR=$(dirname "$NDK_DIR")

# Android NDK
export ANDROID_NDK_HOME=${ANDROID_NDK_HOME:-$HOME/Library/Android/sdk/ndk/26.3.11579264}
TOOLCHAIN=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64
NDK_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake

# Cross-compiler binaries
export CC="$TOOLCHAIN/bin/aarch64-linux-android24-clang"
export CXX="$TOOLCHAIN/bin/aarch64-linux-android24-clang++"
export AR="$TOOLCHAIN/bin/llvm-ar"
export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
export STRIP="$TOOLCHAIN/bin/llvm-strip"

# Android target
ANDROID_ABI=arm64-v8a
ANDROID_PLATFORM=android-24

# Directories
SOURCES_DIR="$OB_DEPS_DIR/sources"
OUTPUT_DIR="$NDK_DIR/output"
BUILD_DIR="$NDK_DIR/_build"

# Shared install prefix -- later deps find earlier deps here
PREFIX="$NDK_DIR/_prefix/usr/local/oceanbase/deps/devel"

# Common flags -- set clean defaults; individual scripts can override
export CFLAGS="-fPIC"
export CXXFLAGS="-fPIC"
export CMAKE_POLICY_VERSION_MINIMUM=3.5

NDK_TARGET_FLAGS="--target=aarch64-linux-android24 --sysroot=${TOOLCHAIN}/sysroot"

# CPU cores for parallel builds
CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)

mkdir -p "$OUTPUT_DIR" "$BUILD_DIR" "$PREFIX/lib" "$PREFIX/include"

# package_dep NAME VERSION
#   Creates devdeps-{NAME}-{VERSION}-{date}.tar.gz in OUTPUT_DIR
#   from the staging directory at $STAGING_DIR.
#   Internal structure: devdeps-{NAME}-{VERSION}/usr/local/oceanbase/deps/devel/{lib,include}/
package_dep() {
    local name=$1
    local version=$2
    local staging=$3  # directory containing lib/ and/or include/
    local date_str=$(date +%Y%m%d)
    local pkg_name="devdeps-${name}-${version}"
    local tarball="${pkg_name}-${date_str}.tar.gz"

    # Create tarball layout
    local layout_dir="$BUILD_DIR/_pkg_${name}"
    rm -rf "$layout_dir"
    mkdir -p "$layout_dir/${pkg_name}/usr/local/oceanbase/deps/devel"

    # Copy lib/ and include/ if they exist
    if [[ -d "$staging/lib" ]]; then
        cp -r "$staging/lib" "$layout_dir/${pkg_name}/usr/local/oceanbase/deps/devel/"
    fi
    if [[ -d "$staging/include" ]]; then
        cp -r "$staging/include" "$layout_dir/${pkg_name}/usr/local/oceanbase/deps/devel/"
    fi

    # Create tarball
    tar -czf "$OUTPUT_DIR/$tarball" -C "$layout_dir" "${pkg_name}"
    echo "Packaged: $OUTPUT_DIR/$tarball"

    rm -rf "$layout_dir"
}

# install_to_prefix STAGING_DIR
#   Copies lib/ and include/ from staging into the shared PREFIX
#   so downstream deps can find headers and libraries.
install_to_prefix() {
    local staging=$1
    if [[ -d "$staging/lib" ]]; then
        cp -r "$staging/lib"/* "$PREFIX/lib/" 2>/dev/null || true
    fi
    if [[ -d "$staging/include" ]]; then
        cp -r "$staging/include"/* "$PREFIX/include/" 2>/dev/null || true
    fi
}

# prepare_source NAME
#   Copies source from submodule to build dir and cd's into it.
#   Returns the build source directory path.
prepare_source() {
    local name=$1
    local src="$SOURCES_DIR/$name"
    local dest="$BUILD_DIR/$name"

    if [[ ! -d "$src" ]]; then
        echo "ERROR: Source directory not found: $src"
        echo "Did you run 'git submodule update --init sources/$name'?"
        exit 1
    fi

    rm -rf "$dest"
    cp -r "$src" "$dest"
    echo "$dest"
}

echo "=== NDK Build Environment ==="
echo "NDK:     $ANDROID_NDK_HOME"
echo "ABI:     $ANDROID_ABI"
echo "API:     $ANDROID_PLATFORM"
echo "PREFIX:  $PREFIX"
echo "OUTPUT:  $OUTPUT_DIR"
echo "============================="
