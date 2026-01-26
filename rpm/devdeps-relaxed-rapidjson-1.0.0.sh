#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-relaxed-rapidjson"}
VERSION=${3:-"1.0.0"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/rapidjson-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download ${PROJECT_NAME} source code"
    wget --no-check-certificate https://github.com/Tencent/rapidjson/archive/27c3a8dc0e2c9218fe94986d249a12b5ed838f1d.zip -O $ROOT_DIR/rapidjson-$VERSION.zip
fi

# init build package env
echo "[BUILD] args: CURDIR=${CUR_DIR} PROJECT_NAME=${PROJECT_NAME} VERSION=${VERSION} RELEASE=${RELEASE}"
CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || grep -c ^processor /proc/cpuinfo)
TOP_DIR=$CUR_DIR/.pkg_build/usr/local/oceanbase/deps/devel
rm -rf $CUR_DIR/.pkg_build && mkdir -p $TOP_DIR

RAPIDJSON_DIR=rapidjson-27c3a8dc0e2c9218fe94986d249a12b5ed838f1d

# compile and install
TMP_DIR=$CUR_DIR/$PROJECT_NAME
rm -rf $TMP_DIR && mkdir -p $TMP_DIR
TMP_INSTALL=$TMP_DIR/tmp_install
rm -rf $TMP_INSTALL && mkdir -p $TMP_INSTALL
cd $TMP_DIR
unzip $ROOT_DIR/rapidjson-$VERSION.zip
cd $RAPIDJSON_DIR
cp $ROOT_DIR/patch/devdeps-relaxed-rapidjson.diff .
patch -p1 < devdeps-relaxed-rapidjson.diff

# copy install file
mkdir -p ${TOP_DIR}/include
cp -r include/rapidjson ${TOP_DIR}/include

# build package
echo "[BUILD] build tarball......"
cd $CUR_DIR/.pkg_build/
tar -zcvf ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ./usr
mv ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ${CUR_DIR}
