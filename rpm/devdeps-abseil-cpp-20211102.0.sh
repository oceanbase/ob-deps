#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-abseil-cpp"}
VERSION=${3:-"20211102.0"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/abseil-cpp-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download ${PROJECT_NAME} source code"
    wget --no-check-certificate https://github.com/abseil/abseil-cpp/archive/refs/tags/${VERSION}.tar.gz -O $ROOT_DIR/abseil-cpp-$VERSION.tar.gz
fi

# init build package env
echo "[BUILD] args: CURDIR=${CUR_DIR} PROJECT_NAME=${PROJECT_NAME} VERSION=${VERSION} RELEASE=${RELEASE}"
CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || grep -c ^processor /proc/cpuinfo)
TOP_DIR=$CUR_DIR/.pkg_build/usr/local/oceanbase/deps/devel
rm -rf $TOP_DIR && mkdir -p $TOP_DIR

export CFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0 -fPIC"
export CXXFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0 -fPIC"

# compile and install
TMP_DIR=$CUR_DIR/$PROJECT_NAME
rm -rf $TMP_DIR && mkdir -p $TMP_DIR
TMP_INSTALL=$TMP_DIR/tmp_install
rm -rf $TMP_INSTALL && mkdir -p $TMP_INSTALL
cd $TMP_DIR
mkdir -p abseil-cpp-$VERSION
tar -xf $ROOT_DIR/abseil-cpp-$VERSION.tar.gz --strip-components=1 -C abseil-cpp-$VERSION
cd abseil-cpp-$VERSION

mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=${TMP_INSTALL} \
         -DABSL_BUILD_TESTING=OFF \
         -DABSL_USE_GOOGLETEST_HEAD=ON \
         -DCMAKE_CXX_STANDARD=14 \
         -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
         -DCMAKE_BUILD_TYPE=RelWithDebInfo
make -j${CPU_CORES}
make install

# copy install file
cp -r $TMP_INSTALL/* ${TOP_DIR}/

# build package
echo "[BUILD] build tarball......"
cd $CUR_DIR/.pkg_build/
tar -zcvf ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ./usr
mv ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ${CUR_DIR}
