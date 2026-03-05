#!/bin/bash
#
# Build AWS SDK C++ for Android arm64-v8a
# Depends on: openssl, libcurl, zlib
#
source "$(dirname "$0")/common.sh"

NAME="aws-sdk-cpp"
VERSION="1.11.156"

echo "=== Building $NAME $VERSION ==="

SRC=$(prepare_source aws-sdk-cpp)
cd "$SRC"

# The submodule checkout should include crt/aws-crt-cpp.
# If not present, clone it.
if [[ ! -d "crt/aws-crt-cpp/include" ]]; then
    echo "Cloning aws-crt-cpp (CRT dependency)..."
    rm -rf crt/aws-crt-cpp
    git clone --recursive https://github.com/awslabs/aws-crt-cpp.git crt/aws-crt-cpp
fi

STAGING="$BUILD_DIR/${NAME}_staging"
rm -rf "$STAGING" && mkdir -p "$STAGING"

mkdir -p build && cd build

cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=$NDK_TOOLCHAIN_FILE \
    -DANDROID_ABI=$ANDROID_ABI \
    -DANDROID_PLATFORM=$ANDROID_PLATFORM \
    -DCMAKE_INSTALL_PREFIX="$STAGING" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DBUILD_ONLY="s3" \
    -DBUILD_DEPS=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DENABLE_TESTING=OFF \
    -DAUTORUN_UNIT_TESTS=OFF \
    -DCMAKE_PREFIX_PATH="$PREFIX" \
    -DCMAKE_FIND_ROOT_PATH="$PREFIX;$TOOLCHAIN/sysroot" \
    -DOPENSSL_ROOT_DIR="$PREFIX" \
    -DOPENSSL_CRYPTO_LIBRARY="$PREFIX/lib/libcrypto.a" \
    -DOPENSSL_SSL_LIBRARY="$PREFIX/lib/libssl.a" \
    -DOPENSSL_INCLUDE_DIR="$PREFIX/include" \
    -Dcrypto_LIBRARY="$PREFIX/lib/libcrypto.a" \
    -Dcrypto_INCLUDE_DIR="$PREFIX/include" \
    -DCURL_LIBRARY="$PREFIX/lib/libcurl.a" \
    -DCURL_INCLUDE_DIR="$PREFIX/include" \
    -DZLIB_ROOT="$PREFIX" \
    -DCMAKE_C_FLAGS="-I$PREFIX/include" \
    -DCMAKE_CXX_FLAGS="-I$PREFIX/include" \
    -DENABLE_OPENSSL_ENCRYPTION=ON

make -j${CPU_CORES}
make install

# Install static libraries to both lib/ and lib64/
mkdir -p "$STAGING/lib" "$STAGING/lib64"
for lib in $(find "$STAGING" -name '*.a' -type f); do
    libname=$(basename "$lib")
    cp "$lib" "$STAGING/lib/$libname" 2>/dev/null || true
    cp "$lib" "$STAGING/lib64/$libname" 2>/dev/null || true
done

install_to_prefix "$STAGING"
package_dep "$NAME" "$VERSION" "$STAGING"
echo "=== $NAME $VERSION done ==="
