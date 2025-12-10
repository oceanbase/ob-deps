#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-libcurl"}
VERSION=${3:-"8.12.1"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/curl-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download ${PROJECT_NAME} source code"
    wget --no-check-certificate https://curl.se/download/curl-$VERSION.tar.gz -O $ROOT_DIR/curl-$VERSION.tar.gz --no-check-certificate
fi

# init build package env
echo "[BUILD] args: CURDIR=${CUR_DIR} PROJECT_NAME=${PROJECT_NAME} VERSION=${VERSION} RELEASE=${RELEASE}"
CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || grep -c ^processor /proc/cpuinfo)
TOP_DIR=$CUR_DIR/.pkg_build/usr/local/oceanbase/deps/devel
rm -rf $TOP_DIR && mkdir -p $TOP_DIR

export LIBS="-framework CoreFoundation -framework SystemConfiguration"
BUILD_OPTION='--build=aarch64-apple-darwin'

# compile and install
TMP_DIR=$CUR_DIR/$PROJECT_NAME
rm -rf $TMP_DIR && mkdir -p $TMP_DIR
TMP_INSTALL=$TMP_DIR/tmp_install
rm -rf $TMP_INSTALL && mkdir -p $TMP_INSTALL
cd $TMP_DIR
tar -xf $ROOT_DIR/curl-$VERSION.tar.gz
cd curl-$VERSION

./configure --prefix=$TMP_INSTALL \
            PKG_CONFIG="pkg-config SSL_LIBS=-l:libssl.a -l:libcrypto.a" \
            --without-libssh2 --without-nss --disable-ftp \
            --disable-ldap --disable-ldaps --without-cyassl \
            --without-polarssl --without-winssl --without-gnutls \
	    --with-ssl=${DEPS_PREFIX} \
            --disable-cookies --disable-rtsp --without-zlib \
            --disable-pop3 --without-libpsl --disable-smtp \
            --disable-imap --disable-telnet \
            --disable-tftp --disable-verbose --disable-gopher \
            --enable-shared=no --with-pic=yes ${BUILD_OPTION}
make -j${CPU_CORES} curl_LDFLAGS=-all-static
make -j${CPU_CORES}
make -j${CPU_CORES} curl_LDFLAGS=-all-static install

# copy install file
cp -r $TMP_INSTALL/lib $TMP_INSTALL/include $TOP_DIR

# build package
echo "[BUILD] build tarball......"
cd $CUR_DIR/.pkg_build/
tar -zcvf ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ./usr
mv ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ${CUR_DIR}
