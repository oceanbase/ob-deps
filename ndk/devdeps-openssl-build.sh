#!/bin/bash
#
# Build OpenSSL (static) for Android arm64-v8a
#
source "$(dirname "$0")/common.sh"

NAME="openssl"
VERSION="1.1.1u"

echo "=== Building $NAME $VERSION ==="

SRC=$(prepare_source openssl)
cd "$SRC"

STAGING="$BUILD_DIR/${NAME}_staging"
rm -rf "$STAGING" && mkdir -p "$STAGING"

# OpenSSL's Configure uses PATH to find the NDK compiler
export PATH=$TOOLCHAIN/bin:$PATH

# Use ./Configure (not ./config) with the android-arm64 target
./Configure android-arm64 \
    -D__ANDROID_API__=24 \
    --prefix="$STAGING" \
    --openssldir="$STAGING" \
    -fPIC \
    no-shared \
    no-tests

make -j${CPU_CORES}
make install_sw

install_to_prefix "$STAGING"
package_dep "$NAME" "$VERSION" "$STAGING"
echo "=== $NAME $VERSION done ==="
