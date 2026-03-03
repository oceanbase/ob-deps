#!/bin/bash
#
# Build Boost for Android arm64-v8a
# Uses b2 with custom user-config.jam for NDK cross-compilation
#
source "$(dirname "$0")/common.sh"

NAME="boost"
VERSION="1.74.0"

echo "=== Building $NAME $VERSION ==="

# boostorg/boost is a superproject -- initialize submodules in the real source
# dir BEFORE prepare_source copies it (the copy breaks .git relative paths)
BOOST_SRC="$SOURCES_DIR/boost"
if [[ -f "$BOOST_SRC/.gitmodules" ]]; then
    echo "Initializing boost submodules in sources/boost..."
    cd "$BOOST_SRC"
    git submodule update --init --depth 1 \
        tools/build tools/boost_install \
        libs/config libs/core libs/headers \
        libs/system libs/thread libs/atomic \
        libs/assert libs/throw_exception libs/smart_ptr \
        libs/type_traits libs/mpl libs/preprocessor \
        libs/move libs/integer libs/static_assert \
        libs/utility libs/io libs/container_hash \
        libs/detail libs/chrono libs/ratio \
        libs/date_time libs/optional libs/lexical_cast \
        libs/numeric libs/math libs/range \
        libs/iterator libs/concept_check libs/function \
        libs/bind libs/type_index libs/container \
        libs/intrusive libs/tuple libs/winapi \
        libs/align libs/dynamic_bitset \
        libs/tokenizer libs/conversion libs/algorithm \
        libs/array libs/unordered libs/exception \
        libs/functional libs/regex libs/predef \
        libs/mp11 libs/variant2 \
        libs/locale \
        libs/geometry libs/polygon libs/qvm \
        libs/multiprecision libs/rational libs/variant \
        libs/fusion libs/function_types libs/typeof \
        libs/serialization libs/spirit libs/random \
        libs/endian libs/foreach libs/phoenix \
        libs/pool libs/proto 2>&1 || true
    cd "$NDK_DIR"
fi

SRC=$(prepare_source boost)
cd "$SRC"

STAGING="$BUILD_DIR/${NAME}_staging"
rm -rf "$STAGING" && mkdir -p "$STAGING/lib" "$STAGING/include"

# Bootstrap builds the b2 tool for the host -- always runs natively
# Unset cross-compiler so bootstrap uses the host compiler
env -u CC -u CXX -u AR -u RANLIB -u STRIP -u CFLAGS -u CXXFLAGS \
./bootstrap.sh --with-libraries=system,thread,atomic

# Write user-config.jam to configure the Android NDK cross-compiler
cat > user-config.jam <<EOF
using clang : android :
    ${TOOLCHAIN}/bin/aarch64-linux-android24-clang++ :
    <cxxflags>"--target=aarch64-linux-android24 --sysroot=${TOOLCHAIN}/sysroot -fPIC -D_LIBCPP_ENABLE_CXX17_REMOVED_UNARY_BINARY_FUNCTION"
    <cflags>"--target=aarch64-linux-android24 --sysroot=${TOOLCHAIN}/sysroot -fPIC"
    <linkflags>"--target=aarch64-linux-android24 --sysroot=${TOOLCHAIN}/sysroot"
    <archiver>${TOOLCHAIN}/bin/llvm-ar
    <ranlib>${TOOLCHAIN}/bin/llvm-ranlib
;
EOF

./b2 \
    --user-config=user-config.jam \
    toolset=clang-android \
    target-os=android \
    architecture=arm \
    address-model=64 \
    -a -j${CPU_CORES} \
    stage \
    --stagedir="$STAGING/_b2" \
    variant=release \
    threading=multi \
    link=static

cp -r "$STAGING/_b2/lib"/*.a "$STAGING/lib/"

# Install ALL boost headers (not just bcp subset) so downstream deps
# like apache-arrow's thrift can find boost/locale.hpp etc.
cp -r boost "$STAGING/include/"

rm -rf "$STAGING/_b2"

install_to_prefix "$STAGING"
package_dep "$NAME" "$VERSION" "$STAGING"
echo "=== $NAME $VERSION done ==="
