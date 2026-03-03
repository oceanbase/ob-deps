#!/bin/bash
#
# Build mxml (static) for Android arm64-v8a
#
source "$(dirname "$0")/common.sh"

NAME="mxml"
VERSION="2.12"

echo "=== Building $NAME $VERSION ==="

SRC=$(prepare_source mxml)
cd "$SRC"

STAGING="$BUILD_DIR/${NAME}_staging"
rm -rf "$STAGING" && mkdir -p "$STAGING"

# Generate configure from git checkout if needed
if [[ ! -f configure ]]; then
    autoconf
fi

./configure \
    --host=aarch64-linux-android \
    --prefix="$STAGING" \
    --enable-static \
    --disable-shared

make -j${CPU_CORES}
make install

# Reorganize: seekdb expects include/mxml/mxml.h
cd "$STAGING"
mkdir -p include/mxml
mv include/mxml.h include/mxml/

install_to_prefix "$STAGING"
package_dep "$NAME" "$VERSION" "$STAGING"
echo "=== $NAME $VERSION done ==="
