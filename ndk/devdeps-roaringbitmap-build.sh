#!/bin/bash
#
# Build CRoaring (roaringbitmap) for Android arm64-v8a
#
source "$(dirname "$0")/common.sh"

NAME="roaringbitmap-croaring"
VERSION="3.0.0"

echo "=== Building $NAME $VERSION ==="

SRC=$(prepare_source roaringbitmap)
cd "$SRC"

# Android Bionic defines _XOPEN_SOURCE and _POSIX_C_SOURCE as empty macros,
# so bare comparisons like `_XOPEN_SOURCE < 700` become `< 700` (syntax error).
# Fix: use `+ 0` trick so empty macros evaluate to 0.
sed -i.bak \
    -e 's/defined(_POSIX_C_SOURCE) && (_POSIX_C_SOURCE < 200809L)/defined(_POSIX_C_SOURCE) \&\& (_POSIX_C_SOURCE + 0 < 200809L)/' \
    -e 's/(_XOPEN_SOURCE < 700)/(_XOPEN_SOURCE + 0 < 700)/' \
    include/roaring/portability.h

STAGING="$BUILD_DIR/${NAME}_staging"
rm -rf "$STAGING" && mkdir -p "$STAGING"

mkdir -p build && cd build

cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=$NDK_TOOLCHAIN_FILE \
    -DANDROID_ABI=$ANDROID_ABI \
    -DANDROID_PLATFORM=$ANDROID_PLATFORM \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_INSTALL_PREFIX="$STAGING" \
    -DCMAKE_LIBRARY_OUTPUT_DIRECTORY="$STAGING" \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DROARING_DISABLE_AVX512=ON \
    -DENABLE_ROARING_TESTS=OFF \
    -DROARING_USE_CPM=OFF \
    -DCMAKE_C_FLAGS="-D__bswap_64=__builtin_bswap64" \
    -DCMAKE_CXX_FLAGS="-D__bswap_64=__builtin_bswap64"

cmake --build . -- -j${CPU_CORES}

# Install headers and library manually (matches seekdb layout)
mkdir -p "$STAGING/include/roaring" "$STAGING/lib"
cp -r ../include/roaring "$STAGING/include/"
cp -r ../cpp/* "$STAGING/include/roaring/"
cp src/*.a "$STAGING/lib/"

install_to_prefix "$STAGING"
package_dep "$NAME" "$VERSION" "$STAGING"
echo "=== $NAME $VERSION done ==="
