#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-sqlite"}
VERSION=${3:-"3.38.1"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/sqlite-version-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download $PROJECT_NAME source code"
    wget https://github.com/sqlite/sqlite/archive/refs/tags/version-3.38.1.tar.gz -O $ROOT_DIR/sqlite-version-$VERSION.tar.gz
fi

# init build package env
echo "[BUILD] args: CURDIR=${CUR_DIR} PROJECT_NAME=${PROJECT_NAME} VERSION=${VERSION} RELEASE=${RELEASE}"
CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || grep -c ^processor /proc/cpuinfo)
TOP_DIR=$CUR_DIR/.pkg_build/usr/local/oceanbase/deps/devel
rm -rf $TOP_DIR && mkdir -p $TOP_DIR

# compile and install
TMP_DIR=$CUR_DIR/$PROJECT_NAME
rm -rf $TMP_DIR && mkdir -p $TMP_DIR
TMP_INSTALL=$TMP_DIR/tmp_install
rm -rf $TMP_INSTALL && mkdir -p $TMP_INSTALL
cd $TMP_DIR
tar -xf $ROOT_DIR/sqlite-version-$VERSION.tar.gz
cd sqlite-version-$VERSION

./configure --prefix=$TMP_INSTALL --enable-shared=no --with-pic
make -j${CPU_CORES}
make install

# copy install file
mkdir -p $TOP_DIR/lib/sqlite
mkdir -p $TOP_DIR/include/sqlite
cp -r $TMP_INSTALL/include/*.h $TOP_DIR/include/sqlite
cp -r $TMP_INSTALL/lib/*.a $TOP_DIR/lib/sqlite

# build package
echo "[BUILD] build tarball......"
cd $CUR_DIR/.pkg_build/
tar -zcvf ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ./usr
mv ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ${CUR_DIR}
