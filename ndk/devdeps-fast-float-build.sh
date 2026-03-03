#!/bin/bash
#
# Build fast_float (header-only) for Android arm64-v8a
#
source "$(dirname "$0")/common.sh"

NAME="fast-float"
VERSION="6.1.3"

echo "=== Building $NAME $VERSION ==="

SRC=$(prepare_source fast-float)
cd "$SRC"
mkdir -p cmake/build && cd cmake/build

STAGING="$BUILD_DIR/${NAME}_staging"
rm -rf "$STAGING" && mkdir -p "$STAGING"

cmake ../.. \
    -DCMAKE_TOOLCHAIN_FILE=$NDK_TOOLCHAIN_FILE \
    -DANDROID_ABI=$ANDROID_ABI \
    -DANDROID_PLATFORM=$ANDROID_PLATFORM \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DFASTFLOAT_TEST=OFF \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_INSTALL_PREFIX="$STAGING" \
    -DBUILD_SHARED_LIBS=OFF

make -j${CPU_CORES}
make install

install_to_prefix "$STAGING"
package_dep "$NAME" "$VERSION" "$STAGING"
echo "=== $NAME $VERSION done ==="
