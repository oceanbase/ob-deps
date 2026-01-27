#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-apache-arrow"}
VERSION=${3:-"9.0.0"}
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

brew install brotli utf8proc re2 lz4 zstd thrift
export CFLAGS="-fPIC"
export CXXFLAGS="-fPIC"
export LDFLAGS="-pie"

# compile and install
TMP_DIR=$CUR_DIR/$PROJECT_NAME
rm -rf $TMP_DIR && mkdir -p $TMP_DIR
TMP_INSTALL=$TMP_DIR/tmp_install
rm -rf $TMP_INSTALL && mkdir -p $TMP_INSTALL
cd $TMP_DIR
tar -xf $ROOT_DIR/apache-arrow-$VERSION.tar.gz
cd apache-arrow-$VERSION/cpp
mkdir build && cd build

cmake .. -DCMAKE_INSTALL_PREFIX=${TMP_INSTALL} \
         --no-warn-unused-cli -Wno-dev \
         -DBoost_DETAILED_FAILURE_MSG=ON \
      	 -DBoost_NO_SYSTEM_COMPONENT=ON \
         -DBoost_NO_SYSTEM_PATHS=ON \
         -DBoost_NO_BOOST_CMAKE=ON \
      	 -DCMAKE_BUILD_TYPE=Release \
         -DARROW_PARQUET=ON \
         -DPARQUET_BUILD_EXAMPLES=OFF \
         -DARROW_FILESYSTEM=ON \
         -DARROW_WITH_BROTLI=ON \
         -DARROW_WITH_BZ2=ON \
         -DARROW_WITH_LZ4=ON \
         -DARROW_WITH_SNAPPY=ON \
         -DARROW_WITH_ZLIB=ON \
         -DARROW_WITH_ZSTD=ON \
         -DARROW_JEMALLOC=OFF \
         -DARROW_SIMD_LEVEL=NONE

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
