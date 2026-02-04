#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-apache-arrow"}
VERSION=${3:-"20.0.0"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/apache-arrow-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download ${PROJECT_NAME} source code"
    wget --no-check-certificate https://archive.apache.org/dist/arrow/arrow-$VERSION/apache-arrow-$VERSION.tar.gz -O $ROOT_DIR/apache-arrow-$VERSION.tar.gz
fi

# init build package env
echo "[BUILD] args: CURDIR=${CUR_DIR} PROJECT_NAME=${PROJECT_NAME} VERSION=${VERSION} RELEASE=${RELEASE}"
CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || grep -c ^processor /proc/cpuinfo)
TOP_DIR=$CUR_DIR/.pkg_build/usr/local/oceanbase/deps/devel
rm -rf $CUR_DIR/.pkg_build && mkdir -p $TOP_DIR

# print commands
set -x

# brew install brotli utf8proc re2 lz4 zstd thrift snappy
export LD=/usr/bin/ld
export AR=/opt/homebrew/opt/llvm/bin/llvm-ar
export RANLIB=/opt/homebrew/opt/llvm/bin/llvm-ranlib
export NM=/opt/homebrew/opt/llvm/bin/llvm-nm
export CFLAGS="-fPIC -D_GNU_SOURCE -fstack-protector-strong -flto=thin -fuse-ld=${LD}"
export CXXFLAGS="-std=c++17 -fPIC -D_GNU_SOURCE -D_GLIBCXX_USE_CXX11_ABI=0 -fstack-protector-strong -flto=thin -fuse-ld=${LD}"
export LDFLAGS="-pie -flto-jobs=8 -fuse-ld=${LD}"

# compile and install
TMP_DIR=$CUR_DIR/$PROJECT_NAME
rm -rf $TMP_DIR && mkdir -p $TMP_DIR
TMP_INSTALL=$TMP_DIR/tmp_install
rm -rf $TMP_INSTALL && mkdir -p $TMP_INSTALL
cd $TMP_DIR
tar -xf $ROOT_DIR/apache-arrow-$VERSION.tar.gz
cd apache-arrow-$VERSION
# cp $ROOT_DIR/cmake/devdeps-apache-arrow.txt ./
# cp $ROOT_DIR/patch/devdeps-apache-arrow-${VERSION}.diff .
# patch -p1 < devdeps-apache-arrow-${VERSION}.diff
cd cpp
mkdir build && cd build

cmake .. -DCMAKE_C_COMPILER=$CC \
         -DCMAKE_CXX_COMPILER=$CXX \
         -DCMAKE_AR=$AR \
         -DCMAKE_RANLIB=$RANLIB \
         -DCMAKE_NM=$NM \
         -DCMAKE_LINKER=$LD \
         -DCMAKE_C_FLAGS="${CFLAGS}" \
         -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
         -DCMAKE_CXX_LINK_FLAGS="${LDFLAGS}" \
         -DCMAKE_EXE_LINKER_FLAGS="${LDFLAGS}" \
         -DCMAKE_SHARED_LINKER_FLAGS="${LDFLAGS}" \
         -DCMAKE_INSTALL_PREFIX=${TMP_INSTALL} \
         -DCMAKE_BUILD_TYPE=Release \
         -DBUILD_SHARED_LIBS=OFF -DARROW_BUILD_SHARED=OFF -DARROW_BUILD_STATIC=ON \
         -DARROW_PARQUET=ON -DPARQUET_BUILD_EXAMPLES=ON -DARROW_FILESYSTEM=ON \
         -DARROW_WITH_BROTLI=ON -DARROW_WITH_BZ2=ON -DARROW_WITH_LZ4=ON \
         -DARROW_WITH_SNAPPY=ON -DARROW_WITH_ZLIB=ON -DARROW_WITH_ZSTD=ON -DARROW_JEMALLOC=OFF

MACOS_VERSION=${MACOS_VERSION:-$(sw_vers -productVersion | awk -F. '{print $1}')}
if [ $MACOS_VERSION -lt 15 ]; then
    sed -i '' 's|set(command "/opt/homebrew/bin/cmake;|set(command "/opt/homebrew/bin/cmake;-DCMAKE_POLICY_VERSION_MINIMUM=3.10;|' ./src/xsimd_ep-stamp/xsimd_ep-configure-RELEASE.cmake
    sed -i '' 's|set(command "/opt/homebrew/bin/cmake;|set(command "/opt/homebrew/bin/cmake;-DCMAKE_POLICY_VERSION_MINIMUM=3.5;|' ./snappy_ep-prefix/src/snappy_ep-stamp/snappy_ep-configure-RELEASE.cmake
fi

max_retries=3
retry_count=0
while true; do
    make -j${CPU_CORES}
    exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo "[Build] Build succeeded."
        break
    fi
    retry_count=$((retry_count+1))
    if [ $retry_count -eq 1 ]; then
        sed -i '' 's|set(command "/opt/homebrew/bin/cmake;|set(command "/opt/homebrew/bin/cmake;-DCMAKE_POLICY_VERSION_MINIMUM=3.5;|' ./src/xsimd_ep-stamp/xsimd_ep-configure-RELEASE.cmake
    fi

    if [ $retry_count -ge $max_retries ]; then
        echo "[Build] Build failed after $max_retries attempts."
        break
    fi

    echo "[Build] Build failed (attempt $retry_count/$max_retries). Retrying..."
done

make install

# copy install file
mkdir -p $TOP_DIR/lib
mkdir -p $TOP_DIR/include/apache-arrow
cp -r ${TMP_INSTALL}/lib/*.a $TOP_DIR/lib
cp -r ${TMP_INSTALL}/include/* $TOP_DIR/include/apache-arrow

# build package
echo "[BUILD] build tarball......"
cd $CUR_DIR/.pkg_build/
tar -zcvf ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ./usr
mv ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ${CUR_DIR}
