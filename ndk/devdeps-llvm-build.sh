#!/bin/bash
#
# Build LLVM 17.0.6 (static) for Android arm64-v8a
#
# Two-stage build:
#   Stage 1 -- Build host llvm-tblgen (runs natively on macOS)
#   Stage 2 -- Cross-compile LLVM static libraries for Android
#
# Required by objit (PL/SQL JIT compilation).
# Components: Support, Core, IRReader, ExecutionEngine, OrcJit, McJit,
#   AArch64CodeGen, AArch64AsmParser, runtimedyld, bitreader, bitwriter,
#   object, objectyaml, target, DebugInfoDWARF, Symbolize
#
source "$(dirname "$0")/common.sh"

NAME="llvm"
VERSION="17.0.6"

echo "=== Building $NAME $VERSION ==="

LLVM_SRC="$SOURCES_DIR/llvm-project/llvm"

if [[ ! -d "$LLVM_SRC" ]]; then
    echo "ERROR: Source directory not found: $LLVM_SRC"
    echo "Did you run 'git submodule update --init sources/llvm-project'?"
    exit 1
fi

STAGING="$BUILD_DIR/${NAME}_staging"
rm -rf "$STAGING" && mkdir -p "$STAGING"

# ================================================================
# Stage 1: Build host llvm-tblgen (runs natively on macOS)
# ================================================================
# LLVM cross-compilation requires a host-native tablegen binary
# to generate .inc files during the cross build.

HOST_BUILD="$BUILD_DIR/${NAME}_host"
HOST_TBLGEN="$HOST_BUILD/bin/llvm-tblgen"

if [[ -x "$HOST_TBLGEN" ]]; then
    echo "--- Stage 1: Reusing existing host llvm-tblgen ---"
else
    rm -rf "$HOST_BUILD" && mkdir -p "$HOST_BUILD"
    cd "$HOST_BUILD"

    echo "--- Stage 1: Building host llvm-tblgen ---"

    # Unset cross-compiler vars so cmake uses the host compiler
    env -u CC -u CXX -u AR -u RANLIB -u STRIP -u CFLAGS -u CXXFLAGS \
    cmake "$LLVM_SRC" \
        -DLLVM_TARGETS_TO_BUILD=AArch64 \
        -DCMAKE_BUILD_TYPE=Release

    env -u CC -u CXX -u AR -u RANLIB -u STRIP -u CFLAGS -u CXXFLAGS \
    make llvm-tblgen -j${CPU_CORES}

    if [[ ! -x "$HOST_TBLGEN" ]]; then
        echo "ERROR: Host llvm-tblgen not found at $HOST_TBLGEN"
        exit 1
    fi
fi

echo "Host tblgen: $HOST_TBLGEN"

# ================================================================
# Stage 2: Cross-compile LLVM for Android arm64-v8a
# ================================================================

CROSS_BUILD="$BUILD_DIR/${NAME}_cross"
rm -rf "$CROSS_BUILD" && mkdir -p "$CROSS_BUILD"
cd "$CROSS_BUILD"

echo "--- Stage 2: Cross-compiling LLVM for Android ---"

cmake "$LLVM_SRC" \
    -DCMAKE_TOOLCHAIN_FILE=$NDK_TOOLCHAIN_FILE \
    -DANDROID_ABI=$ANDROID_ABI \
    -DANDROID_PLATFORM=$ANDROID_PLATFORM \
    -DANDROID_STL=c++_static \
    -DLLVM_TABLEGEN="$HOST_TBLGEN" \
    -DLLVM_HOST_TRIPLE=aarch64-unknown-linux-android \
    -DLLVM_DEFAULT_TARGET_TRIPLE=aarch64-unknown-linux-android \
    -DLLVM_TARGETS_TO_BUILD=AArch64 \
    -DLLVM_ENABLE_RTTI=ON \
    -DLLVM_ENABLE_EH=ON \
    -DLLVM_ENABLE_PROJECTS="" \
    -DBUILD_SHARED_LIBS=OFF \
    -DLLVM_BUILD_TOOLS=OFF \
    -DLLVM_INCLUDE_TOOLS=OFF \
    -DLLVM_INCLUDE_UTILS=OFF \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_EXAMPLES=OFF \
    -DLLVM_INCLUDE_BENCHMARKS=OFF \
    -DLLVM_ENABLE_TERMINFO=OFF \
    -DLLVM_ENABLE_ZLIB=OFF \
    -DLLVM_ENABLE_ZSTD=OFF \
    -DLLVM_ENABLE_LIBXML2=OFF \
    -DLLVM_ENABLE_LIBEDIT=OFF \
    -DLLVM_ENABLE_PLUGINS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$STAGING"

make -j${CPU_CORES}
make install

# Patch: remove llvm-tblgen imported target from cmake exports.
# We don't ship the tblgen binary (it's a host tool, not an Android binary),
# but cmake's LLVMExports.cmake verifies all imported targets exist on disk.
EXPORTS_DIR="$STAGING/lib/cmake/llvm"
# Remove "llvm-tblgen" from the expected targets list
sed -i '' 's/ llvm-tblgen / /g' "$EXPORTS_DIR/LLVMExports.cmake"
# Remove the imported target block
sed -i '' '/^# Create imported target llvm-tblgen$/,/^$/d' "$EXPORTS_DIR/LLVMExports.cmake"
# Remove the release-config import for llvm-tblgen
sed -i '' '/^# Import target "llvm-tblgen"/,/^$/d' "$EXPORTS_DIR/LLVMExports-release.cmake"
# Remove the file check entries
sed -i '' '/llvm-tblgen/d' "$EXPORTS_DIR/LLVMExports-release.cmake"

# Verify key artifacts
for lib in libLLVMCore.a libLLVMAArch64CodeGen.a libLLVMSupport.a; do
    if [[ ! -f "$STAGING/lib/$lib" ]]; then
        echo "ERROR: Expected library not found: $STAGING/lib/$lib"
        exit 1
    fi
done

if [[ ! -f "$STAGING/lib/cmake/llvm/LLVMConfig.cmake" ]]; then
    echo "ERROR: LLVMConfig.cmake not found"
    exit 1
fi

echo "LLVM libraries:"
ls "$STAGING/lib"/libLLVM*.a | wc -l | tr -d ' '
echo " static libraries built"

install_to_prefix "$STAGING"
package_dep "$NAME" "$VERSION" "$STAGING"
echo "=== $NAME $VERSION done ==="
