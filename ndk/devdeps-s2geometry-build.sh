#!/bin/bash
#
# Build s2geometry for Android arm64-v8a
# Depends on: abseil-cpp, openssl
#
source "$(dirname "$0")/common.sh"

NAME="s2geometry"
VERSION="0.10.0"

echo "=== Building $NAME $VERSION ==="

SRC=$(prepare_source s2geometry)
cd "$SRC"

STAGING="$BUILD_DIR/${NAME}_staging"
rm -rf "$STAGING" && mkdir -p "$STAGING"

mkdir -p build && cd build

cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=$NDK_TOOLCHAIN_FILE \
    -DANDROID_ABI=$ANDROID_ABI \
    -DANDROID_PLATFORM=$ANDROID_PLATFORM \
    -DCMAKE_INSTALL_PREFIX="$STAGING" \
    -DCMAKE_PREFIX_PATH="$PREFIX" \
    -DCMAKE_CXX_STANDARD=14 \
    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DOPENSSL_ROOT_DIR="$PREFIX" \
    -Dabsl_DIR="$PREFIX/lib/cmake/absl" \
    -DCMAKE_FIND_ROOT_PATH="$PREFIX;$TOOLCHAIN/sysroot"

make -j${CPU_CORES}
make install

# s2geometry may install to lib/ or lib64/
mkdir -p "$STAGING/include/s2" "$STAGING/lib"
cp -r "$STAGING/include/s2"/* "$STAGING/include/s2/" 2>/dev/null || true
cp "$STAGING/lib/libs2.a" "$STAGING/lib/" 2>/dev/null || \
cp "$STAGING/lib64/libs2.a" "$STAGING/lib/" 2>/dev/null || true

install_to_prefix "$STAGING"
package_dep "$NAME" "$VERSION" "$STAGING"
echo "=== $NAME $VERSION done ==="
