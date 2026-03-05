#!/bin/bash
#
# Build ICU (static) for Android arm64-v8a
# Uses a custom CMakeLists.txt instead of ICU's autotools build system
#
source "$(dirname "$0")/common.sh"

NAME="icu"
VERSION="69.1"

echo "=== Building $NAME $VERSION ==="

SRC=$(prepare_source icu)
cd "$SRC"

# Copy the custom CMakeLists.txt that builds ICU with cmake
cp "$NDK_DIR/support/icu_cmakelists.txt" ./CMakeLists.txt

STAGING="$BUILD_DIR/${NAME}_staging"
rm -rf "$STAGING" && mkdir -p "$STAGING"

mkdir -p build && cd build

cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=$NDK_TOOLCHAIN_FILE \
    -DANDROID_ABI=$ANDROID_ABI \
    -DANDROID_PLATFORM=$ANDROID_PLATFORM \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DICU_VERSION_DIR=icu4c \
    -DCMAKE_INSTALL_PREFIX="$STAGING" \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo

make -j${CPU_CORES} icu_all
make install

# Reorganize headers for seekdb's expected layout: icu/i18n/unicode/...
# cmake install puts them at include/i18n/unicode/ but code expects include/icu/i18n/unicode/
mkdir -p "$STAGING/include_icu/icu"
cp -r "$STAGING"/include/* "$STAGING/include_icu/icu/"
rm -rf "$STAGING/include"
mv "$STAGING/include_icu" "$STAGING/include"

install_to_prefix "$STAGING"
package_dep "$NAME" "$VERSION" "$STAGING"
echo "=== $NAME $VERSION done ==="
