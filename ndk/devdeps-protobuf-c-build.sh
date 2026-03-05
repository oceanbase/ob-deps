#!/bin/bash
#
# Build protobuf-c (static) for Android arm64-v8a
#
source "$(dirname "$0")/common.sh"

NAME="protobuf-c"
VERSION="1.4.1"

echo "=== Building $NAME $VERSION ==="

SRC=$(prepare_source protobuf-c)
cd "$SRC"

STAGING="$BUILD_DIR/${NAME}_staging"
rm -rf "$STAGING" && mkdir -p "$STAGING"

# Generate configure from git checkout (tarballs have it pre-generated)
if [[ ! -f configure ]]; then
    ./autogen.sh
fi

# --disable-protoc skips the protoc-c compiler plugin and all C++ protobuf deps.
# libprotobuf-c.a is pure C and needs no protobuf dependency at all.
./configure \
    --host=aarch64-linux-android \
    --prefix="$STAGING" \
    --enable-static \
    --disable-shared \
    --disable-protoc

make -j${CPU_CORES}
make install

install_to_prefix "$STAGING"
package_dep "$NAME" "$VERSION" "$STAGING"
echo "=== $NAME $VERSION done ==="
