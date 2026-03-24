#!/bin/bash
#
# Build sqlite for Android arm64-v8a
#
source "$(dirname "$0")/common.sh"

NAME="sqlite"
VERSION="3.38.1"

echo "=== Building $NAME $VERSION ==="

SRC=$(prepare_source sqlite)
cd "$SRC"

STAGING="$BUILD_DIR/${NAME}_staging"
rm -rf "$STAGING" && mkdir -p "$STAGING"

mkdir -p build && cd build

# Must pass --host: otherwise configure assumes Darwin and tries to build
# libsqlite3.dylib with -dynamiclib while CC is the NDK toolchain → lld
# links as executable and errors on undefined main.
../configure \
	--host=aarch64-linux-android \
	--prefix="$STAGING" \
	--disable-shared

make -j${CPU_CORES}
make install

mkdir -p $STAGING/lib/sqlite
mkdir -p $STAGING/include/sqlite
mv $STAGING/include/*.h $STAGING/include/sqlite
mv $STAGING/lib/*.a $STAGING/lib/sqlite
[[ -d "$STAGING/lib/pkgconfig" ]] && mv "$STAGING/lib/pkgconfig" "$STAGING/lib/sqlite/"

install_to_prefix "$STAGING"
package_dep "$NAME" "$VERSION" "$STAGING"
echo "=== $NAME $VERSION done ==="
