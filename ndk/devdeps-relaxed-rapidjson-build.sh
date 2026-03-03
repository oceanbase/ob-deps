#!/bin/bash
#
# Build relaxed-rapidjson (header-only + patch) for Android arm64-v8a
#
source "$(dirname "$0")/common.sh"

NAME="relaxed-rapidjson"
VERSION="1.0.0"

echo "=== Building $NAME $VERSION ==="

SRC=$(prepare_source rapidjson)
cd "$SRC"

# Apply the relaxed-rapidjson patch
patch -p1 < "$OB_DEPS_DIR/patch/devdeps-relaxed-rapidjson.diff"

STAGING="$BUILD_DIR/${NAME}_staging"
rm -rf "$STAGING" && mkdir -p "$STAGING/include"

cp -r include/rapidjson "$STAGING/include/"

install_to_prefix "$STAGING"
package_dep "$NAME" "$VERSION" "$STAGING"
echo "=== $NAME $VERSION done ==="
