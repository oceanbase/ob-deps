#!/bin/bash
#
# Build libxml2 (static) for Android arm64-v8a
#
source "$(dirname "$0")/common.sh"

NAME="libxml2"
VERSION="2.10.4"

echo "=== Building $NAME $VERSION ==="

SRC=$(prepare_source libxml2)
cd "$SRC"

STAGING="$BUILD_DIR/${NAME}_staging"
rm -rf "$STAGING" && mkdir -p "$STAGING"

# Generate configure from git checkout if needed
if [[ ! -f configure ]]; then
    autoreconf -fi
fi

./configure \
    --host=aarch64-linux-android \
    --prefix="$STAGING" \
    --without-python \
    --with-pic=yes \
    --enable-static=yes \
    --enable-shared=no \
    --without-zlib \
    --without-lzma

make -j${CPU_CORES}
make install

install_to_prefix "$STAGING"
package_dep "$NAME" "$VERSION" "$STAGING"
echo "=== $NAME $VERSION done ==="
