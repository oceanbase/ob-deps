#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"obdevtools-flex"}
VERSION=${3:-"2.5.35"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/flex-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
  echo "Download $PROJECT_NAME source code"
  wget --no-check-certificate https://src.fedoraproject.org/lookaside/pkgs/flex/flex-2.5.35.tar.bz2/10714e50cea54dc7a227e3eddcd44d57/flex-$VERSION.tar.bz2 -O $ROOT_DIR/flex-$VERSION.tar.bz2
fi

# init build package env
echo "[BUILD] args: CURDIR=${CUR_DIR} PROJECT_NAME=${PROJECT_NAME} VERSION=${VERSION} RELEASE=${RELEASE}"
CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || grep -c ^processor /proc/cpuinfo)
TOP_DIR=$CUR_DIR/.pkg_build/usr/local/oceanbase/devtools
rm -rf $TOP_DIR && mkdir -p $TOP_DIR

# compile and install
TMP_DIR=$CUR_DIR/$PROJECT_NAME
rm -rf $TMP_DIR && mkdir -p $TMP_DIR
TMP_INSTALL=$TMP_DIR/tmp_install
rm -rf $TMP_INSTALL && mkdir -p $TMP_INSTALL
cd $TMP_DIR
tar -xf $ROOT_DIR/flex-$VERSION.tar.bz2
cd flex-$VERSION
mkdir -p build && cd build

# flex 2.5.35 is incompatible with C23, use C99 standard
# Also disable some strict warnings that cause build failures
export CFLAGS="-std=gnu99 -Wno-implicit-function-declaration -Wno-deprecated-non-prototype -Wno-implicit-int"

../configure --prefix=$TMP_INSTALL
make -j${CPU_CORES}
make install

# copy install file
cp -r $TMP_INSTALL/* $TOP_DIR

# build package
echo "[BUILD] build tarball......"
cd $CUR_DIR/.pkg_build/
tar -zcvf ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ./usr
mv ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ${CUR_DIR}
