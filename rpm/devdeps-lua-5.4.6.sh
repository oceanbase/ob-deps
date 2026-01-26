#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-lua"}
VERSION=${3:-"5.4.6"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/lua-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download ${PROJECT_NAME} source code"
    wget --no-check-certificate http://www.lua.org/ftp/lua-${VERSION}.tar.gz -O $ROOT_DIR/lua-$VERSION.tar.gz
fi

# init build package env
echo "[BUILD] args: CURDIR=${CUR_DIR} PROJECT_NAME=${PROJECT_NAME} VERSION=${VERSION} RELEASE=${RELEASE}"
CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || grep -c ^processor /proc/cpuinfo)
TOP_DIR=$CUR_DIR/.pkg_build/usr/local/oceanbase/deps/devel
rm -rf $CUR_DIR/.pkg_build && mkdir -p $TOP_DIR

TO_INC=$(gunzip -c lua-$VERSION.tar.gz | grep -ao '^TO_INC= .*' | cut -d' ' -f2-)
TO_LIB=$(gunzip -c lua-$VERSION.tar.gz | grep -ao '^TO_LIB= .*' | cut -d' ' -f2-)

# compile and install
TMP_DIR=$CUR_DIR/$PROJECT_NAME
rm -rf $TMP_DIR && mkdir -p $TMP_DIR
TMP_INSTALL=$TMP_DIR/tmp_install
rm -rf $TMP_INSTALL && mkdir -p $TMP_INSTALL
cd $TMP_DIR
tar -xf $ROOT_DIR/lua-$VERSION.tar.gz
cd lua-${VERSION}/src

make a MYCFLAGS=-fPIC

# copy install file
mkdir -p $TOP_DIR/lib
mkdir -p $TOP_DIR/include
cp -r $TO_LIB $TOP_DIR/lib
cp -r $TO_INC $TOP_DIR/include

# build package
echo "[BUILD] build tarball......"
cd $CUR_DIR/.pkg_build/
tar -zcvf ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ./usr
mv ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ${CUR_DIR}
