#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-roaringbitmap-croaring"}
VERSION=${3:-"3.0.0"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/CRoaring-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download ${PROJECT_NAME} source code"
    wget --no-check-certificate https://github.com/RoaringBitmap/CRoaring/archive/refs/tags/v$VERSION.tar.gz -O $ROOT_DIR/CRoaring-$VERSION.tar.gz
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
tar -zxf $ROOT_DIR/CRoaring-$VERSION.tar.gz
cd CRoaring-$VERSION
mkdir build && cd build

cmake .. -DCMAKE_INSTALL_PREFIX=$TMP_INSTALL \
         -DCMAKE_LIBRARY_OUTPUT_DIRECTORY=$TMP_INSTALL \
         -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
         -DROARING_DISABLE_AVX512=ON \
         -DENABLE_ROARING_TESTS=OFF \
         -DROARING_USE_CPM=OFF
cmake --build .

# copy install file
mkdir -p $TOP_DIR/include/roaring/
mkdir -p $TOP_DIR/lib/
cp -r ../include/roaring/ $TOP_DIR/include/roaring/
cp -r ../cpp/* $TOP_DIR/include/roaring/
cp src/*.a $TOP_DIR/lib/

# build package
echo "[BUILD] build tarball......"
cd $CUR_DIR/.pkg_build/
tar -zcvf ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ./usr
mv ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ${CUR_DIR}
