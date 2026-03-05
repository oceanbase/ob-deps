#!/bin/bash
#
# Build libcurl (static) for Android arm64-v8a
# Depends on: openssl
#
source "$(dirname "$0")/common.sh"

NAME="libcurl"
VERSION="8.2.1"

echo "=== Building $NAME $VERSION ==="

SRC=$(prepare_source libcurl)
cd "$SRC"

STAGING="$BUILD_DIR/${NAME}_staging"
rm -rf "$STAGING" && mkdir -p "$STAGING"

# Generate configure from git checkout if needed
if [[ ! -f configure ]]; then
    autoreconf -fi
fi

./configure --host=aarch64-linux-android \
            --prefix="$STAGING" \
            --without-libssh2 --without-nss --disable-ftp --disable-ldap \
            --disable-ldaps --without-gnutls --with-ssl="$PREFIX" \
            --disable-cookies --disable-rtsp --disable-pop3 --disable-smtp \
            --disable-imap --disable-telnet --disable-tftp --disable-verbose \
            --disable-gopher --enable-shared=no --with-pic=yes

make -j${CPU_CORES}
make install

install_to_prefix "$STAGING"
package_dep "$NAME" "$VERSION" "$STAGING"
echo "=== $NAME $VERSION done ==="
