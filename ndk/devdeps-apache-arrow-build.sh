#!/bin/bash
#
# Build Apache Arrow for Android arm64-v8a
# Depends on: zlib, boost (headers)
# Builds its own snappy, lz4, brotli, bz2, zstd internally
#
source "$(dirname "$0")/common.sh"

NAME="apache-arrow"
VERSION="20.0.0"

echo "=== Building $NAME $VERSION ==="

SRC=$(prepare_source apache-arrow)
cd "$SRC"

# Patch: exclude vendored musl strptime.c on Android (Bionic has strptime,
# and the musl version uses nl_langinfo which requires API 26+)
ARROW_CMAKE=cpp/src/arrow/CMakeLists.txt
sed 's|vendored/musl/strptime.c|# vendored/musl/strptime.c  # disabled for Android|' \
    "$ARROW_CMAKE" > "$ARROW_CMAKE.tmp"
mv "$ARROW_CMAKE.tmp" "$ARROW_CMAKE"

# Patch ThirdpartyToolchain.cmake: pass ANDROID_ABI and ANDROID_PLATFORM to
# ExternalProject sub-builds so they compile for the correct architecture
TOOLCHAIN_CMAKE=cpp/cmake_modules/ThirdpartyToolchain.cmake
sed 's|list(APPEND EP_COMMON_CMAKE_ARGS -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE})|list(APPEND EP_COMMON_CMAKE_ARGS -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}\n                                    -DANDROID_ABI=${ANDROID_ABI}\n                                    -DANDROID_PLATFORM=${ANDROID_PLATFORM})|' \
    "$TOOLCHAIN_CMAKE" > "$TOOLCHAIN_CMAKE.tmp"
mv "$TOOLCHAIN_CMAKE.tmp" "$TOOLCHAIN_CMAKE"

# Patch vendored date library for Android:
# 1. Forward declaration of init_tzdb() is incorrectly excluded on Android
TZ_CPP=cpp/src/arrow/vendored/datetime/tz.cpp
perl -0777 -pi -e 's/#if !defined\(ANDROID\) && !defined\(__ANDROID__\)\nstatic std::unique_ptr<tzdb> init_tzdb\(\);\n#endif \/\/ !defined\(ANDROID\) && !defined\(__ANDROID__\)/static std::unique_ptr<tzdb> init_tzdb();/' "$TZ_CPP"

# 2. parse_from_android_tzdata is private but called from init_tzdb()
TZ_H=cpp/src/arrow/vendored/datetime/tz.h
perl -0777 -pi -e 's/(# if defined\(ANDROID\) \|\| defined\(__ANDROID__\)\n    void parse_from_android_tzdata)/public:\n$1/' "$TZ_H"

cd cpp
mkdir -p build && cd build

STAGING="$BUILD_DIR/${NAME}_staging"
rm -rf "$STAGING" && mkdir -p "$STAGING"

# Export for make-based sub-builds (lz4, bzip2) that read CC/CFLAGS from env
export CC="$TOOLCHAIN/bin/clang"
export CXX="$TOOLCHAIN/bin/clang++"
export CFLAGS="${NDK_TARGET_FLAGS} -fPIC -Wno-int-conversion"
export CXXFLAGS="${NDK_TARGET_FLAGS} -fPIC"

cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=$NDK_TOOLCHAIN_FILE \
    -DANDROID_ABI=$ANDROID_ABI \
    -DANDROID_PLATFORM=$ANDROID_PLATFORM \
    -DCMAKE_INSTALL_PREFIX="$STAGING" \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_C_FLAGS="${NDK_TARGET_FLAGS} -fPIC -Wno-int-conversion" \
    -DCMAKE_CXX_FLAGS="${NDK_TARGET_FLAGS} -fPIC" \
    -DARROW_PARQUET=ON \
    -DPARQUET_BUILD_EXAMPLES=OFF \
    -DARROW_FILESYSTEM=ON \
    -DARROW_JEMALLOC=OFF \
    -DARROW_MIMALLOC=OFF \
    -DARROW_BUILD_SHARED=OFF \
    -DARROW_BUILD_STATIC=ON \
    -DARROW_WITH_BROTLI=ON \
    -DARROW_WITH_BZ2=ON \
    -DARROW_WITH_LZ4=ON \
    -DARROW_WITH_SNAPPY=ON \
    -DARROW_WITH_ZLIB=ON \
    -DARROW_WITH_ZSTD=ON \
    -DARROW_DEPENDENCY_SOURCE=AUTO \
    -DZLIB_ROOT="$PREFIX" \
    -DARROW_BOOST_USE_SHARED=OFF \
    -DCMAKE_FIND_ROOT_PATH="$PREFIX;$TOOLCHAIN/sysroot" \
    -DCMAKE_POLICY_DEFAULT_CMP0167=OLD

make -j${CPU_CORES}
make install

# Install libraries (arrow may put them in lib/ or lib64/)
mkdir -p "$STAGING/lib" "$STAGING/lib64"
for DEST in "$STAGING/lib" "$STAGING/lib64"; do
    cp "$STAGING/lib/libarrow.a" "$DEST/" 2>/dev/null || \
    cp "$STAGING/lib64/libarrow.a" "$DEST/" 2>/dev/null || true
    cp "$STAGING/lib/libparquet.a" "$DEST/" 2>/dev/null || \
    cp "$STAGING/lib64/libparquet.a" "$DEST/" 2>/dev/null || true
done

# Install bundled dependencies (built by arrow but not installed by default)
# The file may be in build/ or build/relwithdebinfo/ depending on CMake generator
BUNDLED_LIB=$(find "$BUILD_DIR/$NAME/cpp/build" -name "libarrow_bundled_dependencies.a" -print -quit 2>/dev/null)
if [[ -n "$BUNDLED_LIB" ]]; then
    cp "$BUNDLED_LIB" "$STAGING/lib/"
    cp "$BUNDLED_LIB" "$STAGING/lib64/"
fi

# Reorganize includes for seekdb (expects include/apache-arrow/)
if [[ -d "$STAGING/include/arrow" ]]; then
    mkdir -p "$STAGING/include/apache-arrow"
    cp -r "$STAGING/include"/* "$STAGING/include/apache-arrow/" 2>/dev/null || true
fi

install_to_prefix "$STAGING"
package_dep "$NAME" "$VERSION" "$STAGING"
echo "=== $NAME $VERSION done ==="
