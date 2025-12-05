#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-s3-cpp-sdk"}
VERSION=${3:-"1.11.156"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/aws-sdk-cpp-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download ${PROJECT_NAME} source code"
    wget --no-check-certificate https://github.com/aws/aws-sdk-cpp/archive/refs/tags/$VERSION.tar.gz -O $ROOT_DIR/aws-sdk-cpp-$VERSION.tar.gz
fi

# init build package env
echo "[BUILD] args: CURDIR=${CUR_DIR} PROJECT_NAME=${PROJECT_NAME} VERSION=${VERSION} RELEASE=${RELEASE}"
CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || grep -c ^processor /proc/cpuinfo)
TOP_DIR=$CUR_DIR/.pkg_build/usr/local/oceanbase/deps/devel
rm -rf $TOP_DIR && mkdir -p $TOP_DIR

export CXXFLAGS="-fPIC"
export CFLAGS="-fPIC"
export LDFLAGS="-pie"
OPENSSL_DIR="$(brew --prefix openssl@3)"

# compile and install
TMP_DIR=$CUR_DIR/$PROJECT_NAME
rm -rf $TMP_DIR && mkdir -p $TMP_DIR
TMP_INSTALL=$TMP_DIR/tmp_install
rm -rf $TMP_INSTALL && mkdir -p $TMP_INSTALL
cd $TMP_DIR
tar -xf $ROOT_DIR/aws-sdk-cpp-$VERSION.tar.gz
cd aws-sdk-cpp-$VERSION

sh prefetch_crt_dependency.sh
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release \
         -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
         -DOPENSSL_ROOT_DIR=${OPENSSL_DIR} \
         -DCURL_INCLUDE_DIR=${DEPS_PREFIX}/include \
         -DCURL_LIBRARY=${DEPS_PREFIX}/lib/libcurl.a \
         -DCMAKE_INSTALL_PREFIX=${TMP_INSTALL} \
         -DCMAKE_PREFIX_PATH=${OPENSSL_DIR} \
         -DBUILD_ONLY="s3" -DBUILD_SHARED_LIBS=0 -DENABLE_TESTING=0 \
         -DCUSTOM_MEMORY_MANAGEMENT=1 -DAWS_CUSTOM_MEMORY_MANAGEMENT=1
make -j$CPU_CORES
make install

# copy install file
cp -r ${TMP_INSTALL}/lib64 ${TMP_INSTALL}/include ${TOP_DIR}

# build package
echo "[BUILD] build tarball......"
cd $CUR_DIR/.pkg_build/
tar -zcvf ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ./usr
mv ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ${CUR_DIR}
