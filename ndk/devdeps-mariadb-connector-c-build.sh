#!/bin/bash
#
# Build mariadb-connector-c (static) for Android arm64-v8a
# Depends on: openssl, zlib
#
source "$(dirname "$0")/common.sh"

NAME="mariadb-connector-c"
VERSION="3.1.12"

echo "=== Building $NAME $VERSION ==="

SRC=$(prepare_source mariadb-connector-c)
cd "$SRC"

# Fix cmake syntax error in ConnectorName.cmake
sed 's/END()/ENDIF()/g' cmake/ConnectorName.cmake > cmake/ConnectorName.cmake.tmp
mv cmake/ConnectorName.cmake.tmp cmake/ConnectorName.cmake

STAGING="$BUILD_DIR/${NAME}_staging"
rm -rf "$STAGING" && mkdir -p "$STAGING"

mkdir -p build && cd build

cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=$NDK_TOOLCHAIN_FILE \
    -DANDROID_ABI=$ANDROID_ABI \
    -DANDROID_PLATFORM=$ANDROID_PLATFORM \
    -DCMAKE_INSTALL_PREFIX="$STAGING" \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_C_FLAGS="-Dushort='unsigned short'" \
    -DWITH_SSL=OPENSSL \
    -DOPENSSL_ROOT_DIR="$PREFIX" \
    -DOPENSSL_INCLUDE_DIR="$PREFIX/include" \
    -DOPENSSL_SSL_LIBRARY="$PREFIX/lib/libssl.a" \
    -DOPENSSL_CRYPTO_LIBRARY="$PREFIX/lib/libcrypto.a" \
    -DENABLED_LOCAL_INFILE=1 \
    -DDEFAULT_CHARSET=utf8 \
    -DWITH_UNIT_TESTS=OFF \
    -DWITH_CURL=OFF \
    -DWITH_EXTERNAL_ZLIB=ON \
    -DZLIB_LIBRARY="$PREFIX/lib/libz.a" \
    -DZLIB_INCLUDE_DIR="$PREFIX/include"

make -j${CPU_CORES}
make install

# Reorganize: seekdb expects lib/libmariadbclient.a and include/mariadb/
# mariadb installs static lib to lib/mariadb/ by default; copy to lib/
if [[ -f "$STAGING/lib/mariadb/libmariadbclient.a" ]] && [[ ! -f "$STAGING/lib/libmariadbclient.a" ]]; then
    cp "$STAGING/lib/mariadb/libmariadbclient.a" "$STAGING/lib/"
fi

install_to_prefix "$STAGING"
package_dep "$NAME" "$VERSION" "$STAGING"
echo "=== $NAME $VERSION done ==="
