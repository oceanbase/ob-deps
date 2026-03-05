#!/bin/bash
#
# Build zlib (static) for Android arm64-v8a
#
source "$(dirname "$0")/common.sh"

NAME="zlib"
VERSION="1.2.13"

echo "=== Building $NAME $VERSION ==="

SRC=$(prepare_source zlib)
cd "$SRC"

STAGING="$BUILD_DIR/${NAME}_staging"
rm -rf "$STAGING" && mkdir -p "$STAGING"

./configure --prefix="$STAGING" --static

# Override AR/ARFLAGS: zlib's configure hardcodes macOS libtool,
# but we need llvm-ar for cross-compiled ELF objects
make AR="$AR" ARFLAGS="rcs" -j${CPU_CORES}
make install

install_to_prefix "$STAGING"
package_dep "$NAME" "$VERSION" "$STAGING"
echo "=== $NAME $VERSION done ==="
