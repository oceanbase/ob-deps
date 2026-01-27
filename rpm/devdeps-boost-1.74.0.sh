#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-boost"}
VERSION=${3:-"1.74.0"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/boost_1_74_0.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download ${PROJECT_NAME} source code"
    wget --no-check-certificate https://archives.boost.io/release/$VERSION/source/boost_1_74_0.tar.bz2 -O $ROOT_DIR/boost-$VERSION.tar.bz2
fi

# init build package env
echo "[BUILD] args: CURDIR=${CUR_DIR} PROJECT_NAME=${PROJECT_NAME} VERSION=${VERSION} RELEASE=${RELEASE}"
CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || grep -c ^processor /proc/cpuinfo)
TOP_DIR=$CUR_DIR/.pkg_build/usr/local/oceanbase/deps/devel
rm -rf $CUR_DIR/.pkg_build && mkdir -p $TOP_DIR

# compile and install
TMP_DIR=$CUR_DIR/$PROJECT_NAME
rm -rf $TMP_DIR && mkdir -p $TMP_DIR
TMP_INSTALL=$TMP_DIR/tmp_install
rm -rf $TMP_INSTALL && mkdir -p $TMP_INSTALL
cd $TMP_DIR
tar -xf $ROOT_DIR/boost_1_74_0.tar.bz2
cd boost_1_74_0
cp $ROOT_DIR/patch/devdeps-boost.diff .
patch -p1 < devdeps-boost.diff
mkdir build

./bootstrap.sh --prefix=${TMP_INSTALL} --with-libraries=system,thread
./b2 cxxflags=-fPIC cflags=-fPIC cxxstd=14 -a stage --stagedir=${TMP_DIR}/boost_1_74_0/build variant=release threading=multi link=static
mkdir -p $TMP_INSTALL/lib
cp -r ${TMP_DIR}/boost_1_74_0/build/lib/*.a $TMP_INSTALL/lib

# install geometry files
./b2 cxxflags=-fPIC cxxstd=14 tools/bcp
mkdir -p $TMP_INSTALL/include
./dist/bin/bcp boost/geometry.hpp boost/geometry.hpp boost/geometry \
               boost/spirit/include/qi.hpp boost/spirit/include/phoenix.hpp \
               boost/bind/bind.hpp boost/fusion/include/adapt_struct.hpp \
               boost/lambda/lambda.hpp \
               $TMP_INSTALL/include
cd $TMP_INSTALL/include
# delete unnecessary files
rm -rf Jamroot
rm -rf libs

# copy install file
cp -r $TMP_INSTALL/* ${TOP_DIR}/

# build package
echo "[BUILD] build tarball......"
cd $CUR_DIR/.pkg_build/
tar -zcvf ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ./usr
mv ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ${CUR_DIR}
