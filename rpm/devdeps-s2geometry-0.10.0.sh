#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-s2geometry"}
VERSION=${3:-"0.10.0"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/s2geometry-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download ${PROJECT_NAME} source code"
    wget --no-check-certificate https://github.com/google/s2geometry/archive/refs/tags/v${VERSION}.tar.gz -O $ROOT_DIR/s2geometry-$VERSION.tar.gz
fi

# init build package env
echo "[BUILD] args: CURDIR=${CUR_DIR} PROJECT_NAME=${PROJECT_NAME} VERSION=${VERSION} RELEASE=${RELEASE}"
CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || grep -c ^processor /proc/cpuinfo)
TOP_DIR=$CUR_DIR/.pkg_build/usr/local/oceanbase/deps/devel
rm -rf $CUR_DIR/.pkg_build && mkdir -p $TOP_DIR

export CFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0 -fPIC"
export CXXFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0 -fPIC"

# compile and install
TMP_DIR=$CUR_DIR/$PROJECT_NAME
rm -rf $TMP_DIR && mkdir -p $TMP_DIR
TMP_INSTALL=$TMP_DIR/tmp_install
rm -rf $TMP_INSTALL && mkdir -p $TMP_INSTALL
cd $TMP_DIR
tar -xf $ROOT_DIR/s2geometry-$VERSION.tar.gz
cd s2geometry-$VERSION
mkdir -p build && cd build

cmake .. -DCMAKE_INSTALL_PREFIX=${TMP_INSTALL} \
	 -DCMAKE_PREFIX_PATH=${DEPS_PREFIX} \
         -DCMAKE_CXX_STANDARD=14 \
         -DCMAKE_CXX_STANDARD_REQUIRED=ON \
         -DBUILD_SHARED_LIBS=OFF \
         -DBUILD_EXAMPLES=OFF \
         -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
         -DCMAKE_BUILD_TYPE=Release
make -j${CPU_CORES}
make install

# copy install file
mkdir -p $TOP_DIR/include/
mkdir -p $TOP_DIR/lib64
cp -r ${TMP_INSTALL}/include/s2 $TOP_DIR/include/
cp -r ${TMP_INSTALL}/lib/* $TOP_DIR/lib64

# build package
echo "[BUILD] build tarball......"
cd $CUR_DIR/.pkg_build/
tar -zcvf ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ./usr
mv ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ${CUR_DIR}
