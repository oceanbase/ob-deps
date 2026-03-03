#!/bin/bash
#
# Build xz/liblzma (static) for Android arm64-v8a
#
source "$(dirname "$0")/common.sh"

NAME="xz"
VERSION="5.2.2"

echo "=== Building $NAME $VERSION ==="

SRC=$(prepare_source xz)
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
    --enable-static \
    --disable-shared \
    --with-pic=yes \
    --disable-xz \
    --disable-xzdec \
    --disable-lzmadec \
    --disable-lzmainfo \
    --disable-scripts \
    --disable-doc

make -j${CPU_CORES}
make install

install_to_prefix "$STAGING"
package_dep "$NAME" "$VERSION" "$STAGING"
echo "=== $NAME $VERSION done ==="
