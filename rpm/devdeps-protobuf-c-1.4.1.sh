#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-protobuf-c"}
VERSION=${3:-"1.4.1"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/protobuf-all-3.20.3.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download ${PROJECT_NAME}-all source code"
    wget https://github.com/protocolbuffers/protobuf/releases/download/v3.20.3/protobuf-all-3.20.3.tar.gz -O $ROOT_DIR/protobuf-all-3.20.3.tar.gz
fi

if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/protobuf-c-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download ${PROJECT_NAME} source code"
    wget --no-check-certificate https://github.com/protobuf-c/protobuf-c/archive/refs/tags/v${VERSION}.tar.gz -O $ROOT_DIR/protobuf-c-$VERSION.tar.gz
fi

# init build package env
echo "[BUILD] args: CURDIR=${CUR_DIR} PROJECT_NAME=${PROJECT_NAME} VERSION=${VERSION} RELEASE=${RELEASE}"
CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || grep -c ^processor /proc/cpuinfo)
TOP_DIR=$CUR_DIR/.pkg_build/usr/local/oceanbase/deps/devel
rm -rf $CUR_DIR/.pkg_build && mkdir -p $TOP_DIR

export CXXFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0"
brew install automake autoconf libtool

# compile and install
TMP_DIR=$CUR_DIR/$PROJECT_NAME
rm -rf $TMP_DIR && mkdir -p $TMP_DIR
TMP_INSTALL=$TMP_DIR/tmp_install
rm -rf $TMP_INSTALL && mkdir -p $TMP_INSTALL

mkdir -p $TMP_INSTALL/lib/protobuf-c
mkdir -p $TMP_INSTALL/include/protobuf-c

cd $TMP_DIR
tar -xf $ROOT_DIR/protobuf-all-3.20.3.tar.gz
cd protobuf-3.20.3
mkdir build_tmp && cd build_tmp
../configure --prefix=$TMP_INSTALL/proto CXXFLAGS="$CXXFLAGS"
make -j${CPU_CORES}
make install

cd $TMP_DIR
tar -xf $ROOT_DIR/protobuf-c-$VERSION.tar.gz
cd protobuf-c-$VERSION
./autogen.sh
export PKG_CONFIG_PATH=$TMP_INSTALL/proto/lib/pkgconfig
mkdir build_tmp && cd build_tmp
# Set LDFLAGS and LIBS to link protobuf library
export LDFLAGS="-L$TMP_INSTALL/proto/lib"
export LIBS="-lprotobuf -lprotoc"
../configure --prefix=$TMP_INSTALL --enable-shared=yes CFLAGS="-g -O2 -fPIC" CXXFLAGS="-g -O2 -fPIC" LDFLAGS="$LDFLAGS" LIBS="$LIBS"
# Fix Makefile to ensure protobuf library is linked for protoc-gen-c
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i.bak "s|^protoc_c_protoc_gen_c_LDADD = \\\\|protoc_c_protoc_gen_c_LDADD = -L$TMP_INSTALL/proto/lib -lprotobuf -lprotoc \\\\|" Makefile
else
  sed -i "s|^protoc_c_protoc_gen_c_LDADD = \\\\|protoc_c_protoc_gen_c_LDADD = -L$TMP_INSTALL/proto/lib -lprotobuf -lprotoc \\\\|" Makefile
fi
make -j${CPU_CORES}
make install

# copy install file
mkdir -p $TOP_DIR/include/protobuf-c
mkdir -p $TOP_DIR/lib/
cp -r $TMP_INSTALL/include/protobuf-c/*.h $TOP_DIR/include/protobuf-c/
cp -r $TMP_INSTALL/lib/*.a $TOP_DIR/lib/

# build package
echo "[BUILD] build tarball......"
cd $CUR_DIR/.pkg_build/
tar -zcvf ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ./usr
mv ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ${CUR_DIR}
