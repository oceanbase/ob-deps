#!/bin/bash
#
# Build Apache ORC for Android arm64-v8a
# Depends on: zlib, arrow (for headers)
# Builds protobuf internally (host protoc + target libprotobuf)
#
source "$(dirname "$0")/common.sh"

NAME="apache-orc"
VERSION="1.8.8"

echo "=== Building $NAME $VERSION ==="

SRC=$(prepare_source apache-orc)
cd "$SRC"

# Copy the custom ThirdpartyToolchain.cmake that uses pre-built/system deps
cp "$NDK_DIR/support/ThirdpartyToolchain.cmake" cmake_modules/

STAGING="$BUILD_DIR/${NAME}_staging"
rm -rf "$STAGING" && mkdir -p "$STAGING"

# Step 1: Build protobuf for HOST to get protoc binary
echo "--- Building host protobuf (for protoc) ---"
PROTOBUF_HOST_DIR="$BUILD_DIR/protobuf_host"
PROTOBUF_SRC="$BUILD_DIR/protobuf-3.5.1"
rm -rf "$PROTOBUF_SRC" "$PROTOBUF_HOST_DIR"

# ORC bundles protobuf source; extract from the orc tree or use submodule
# The ORC source tree has references to protobuf 3.5.1
if [[ -d "$SRC/build/protobuf" ]]; then
    cp -r "$SRC/build/protobuf" "$PROTOBUF_SRC"
elif [[ -f "$NDK_DIR/support/protobuf-3.5.1.tar.gz" ]]; then
    mkdir -p "$PROTOBUF_SRC"
    tar -xf "$NDK_DIR/support/protobuf-3.5.1.tar.gz" --strip-components=1 -C "$PROTOBUF_SRC"
else
    echo "Downloading protobuf 3.5.1 for ORC..."
    mkdir -p "$PROTOBUF_SRC"
    curl -sL https://github.com/google/protobuf/archive/v3.5.1.tar.gz | \
        tar -xz --strip-components=1 -C "$PROTOBUF_SRC"
fi

mkdir -p "$PROTOBUF_SRC/cmake/build_host" && cd "$PROTOBUF_SRC/cmake/build_host"
# Host build -- unset cross-compiler env vars
env -u CC -u CXX -u AR -u RANLIB -u STRIP -u CFLAGS -u CXXFLAGS \
cmake .. -DCMAKE_INSTALL_PREFIX="$PROTOBUF_HOST_DIR" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DBUILD_SHARED_LIBS=OFF \
    -Dprotobuf_BUILD_TESTS=OFF \
    -DCMAKE_BUILD_TYPE=Release
make -j${CPU_CORES}
make install

# Step 2: Build protobuf for TARGET (Android aarch64)
echo "--- Building target protobuf (for libprotobuf.a) ---"
PROTOBUF_TARGET_DIR="$BUILD_DIR/protobuf_target"
rm -rf "$PROTOBUF_TARGET_DIR"
cd "$PROTOBUF_SRC/cmake"
rm -rf build_target && mkdir build_target && cd build_target

cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=$NDK_TOOLCHAIN_FILE \
    -DANDROID_ABI=$ANDROID_ABI \
    -DANDROID_PLATFORM=$ANDROID_PLATFORM \
    -DCMAKE_INSTALL_PREFIX="$PROTOBUF_TARGET_DIR" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_C_FLAGS="${NDK_TARGET_FLAGS} -fPIC" \
    -DCMAKE_CXX_FLAGS="${NDK_TARGET_FLAGS} -fPIC" \
    -DBUILD_SHARED_LIBS=OFF \
    -Dprotobuf_BUILD_TESTS=OFF \
    -Dprotobuf_BUILD_PROTOC_BINARIES=OFF \
    -DCMAKE_BUILD_TYPE=Release
make -j${CPU_CORES} libprotobuf
# Manual install -- only libprotobuf.a and headers
mkdir -p "$PROTOBUF_TARGET_DIR/lib" "$PROTOBUF_TARGET_DIR/include"
cp libprotobuf.a "$PROTOBUF_TARGET_DIR/lib/"
cp -r "$PROTOBUF_SRC/src/google" "$PROTOBUF_TARGET_DIR/include/"

# Step 3: Create merged prefix with host protoc + target lib
echo "--- Creating merged protobuf prefix ---"
PROTOBUF_MERGED="$BUILD_DIR/protobuf_merged"
rm -rf "$PROTOBUF_MERGED"
mkdir -p "$PROTOBUF_MERGED/bin" "$PROTOBUF_MERGED/lib" "$PROTOBUF_MERGED/include"
cp "$PROTOBUF_HOST_DIR/bin/protoc" "$PROTOBUF_MERGED/bin/"
cp "$PROTOBUF_TARGET_DIR/lib/libprotobuf.a" "$PROTOBUF_MERGED/lib/"
cp "$PROTOBUF_HOST_DIR/lib/libprotoc.a" "$PROTOBUF_MERGED/lib/"
cp -r "$PROTOBUF_TARGET_DIR/include"/* "$PROTOBUF_MERGED/include/"

# Step 4: Build ORC
echo "--- Building ORC ---"
cd "$SRC"
mkdir -p build && cd build

export ZLIB_HOME="$PREFIX"
export PROTOBUF_HOME="$PROTOBUF_MERGED"

cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=$NDK_TOOLCHAIN_FILE \
    -DANDROID_ABI=$ANDROID_ABI \
    -DANDROID_PLATFORM=$ANDROID_PLATFORM \
    -DCMAKE_INSTALL_PREFIX="$STAGING" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_C_FLAGS="${NDK_TARGET_FLAGS} -fPIC -Wno-int-conversion" \
    -DCMAKE_CXX_FLAGS="${NDK_TARGET_FLAGS} -fPIC" \
    -DCMAKE_FIND_ROOT_PATH="$PREFIX;$PROTOBUF_MERGED;$TOOLCHAIN/sysroot" \
    -DBUILD_JAVA=OFF \
    -DBUILD_CPP_TESTS=OFF \
    -DBUILD_TOOLS=OFF \
    -DSTOP_BUILD_ON_WARNING=OFF \
    -DBUILD_POSITION_INDEPENDENT_LIB=ON \
    -DBUILD_LIBHDFSPP=OFF \
    -DHAS_POST_2038=1 \
    -DHAS_POST_2038_EXITCODE=0 \
    -DNEEDS_Z_PREFIX=0 \
    -DNEEDS_Z_PREFIX_EXITCODE=1 \
    -DHAS_PRE_1970=1 \
    -DHAS_PRE_1970_EXITCODE=0

make -j${CPU_CORES}
make install

# Install protobuf target libs (needed by seekdb linker)
mkdir -p "$STAGING/lib" "$STAGING/lib64"
cp "$PROTOBUF_TARGET_DIR/lib/libprotobuf.a" "$STAGING/lib/"
cp "$PROTOBUF_TARGET_DIR/lib/libprotobuf.a" "$STAGING/lib64/"

# Install to staging
mkdir -p "$STAGING/include/apache-orc"
cp "$STAGING/lib/liborc.a" "$STAGING/lib/" 2>/dev/null || \
cp "$STAGING/lib64/liborc.a" "$STAGING/lib/" 2>/dev/null || true
cp -r "$STAGING/include/orc" "$STAGING/include/apache-orc/" 2>/dev/null || true

install_to_prefix "$STAGING"
package_dep "$NAME" "$VERSION" "$STAGING"
echo "=== $NAME $VERSION done ==="
