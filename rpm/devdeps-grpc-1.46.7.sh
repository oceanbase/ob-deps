#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-grpc"}
VERSION=${3:-"1.46.7"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/grpc-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    cd $ROOT_DIR
    git clone https://github.com/grpc/grpc.git -b v1.46.7 --depth 1 grpc-$VERSION
    cd grpc-$VERSION
    git submodule update --init --recursive --depth=1
    cd $ROOT_DIR
    tar -zcvf grpc-$VERSION.tar.gz grpc-$VERSION
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
tar -xf $ROOT_DIR/grpc-$VERSION.tar.gz
cd grpc-$VERSION

# 修复过时的 cmake_minimum_required (新版 CMake 已移除对 < 3.5 的支持)
# 使用 /i 忽略大小写，因 c-ares 使用 CMAKE_MINIMUM_REQUIRED (大写)
for f in third_party/zlib/CMakeLists.txt third_party/cares/cares/CMakeLists.txt third_party/protobuf/cmake/CMakeLists.txt; do
    [ -f "$f" ] && perl -i -pe 's/cmake_minimum_required\s*\(\s*VERSION\s+2\.4\.4\s*\)/cmake_minimum_required(VERSION 3.5.1)/gi; s/cmake_minimum_required\s*\(\s*VERSION\s+3\.1\.0\s*\)/cmake_minimum_required(VERSION 3.5.1)/gi; s/cmake_minimum_required\s*\(\s*VERSION\s+3\.1\.3\s*\)/cmake_minimum_required(VERSION 3.5.1)/gi' "$f" 2>/dev/null || true
done

# Install c-ares
cd third_party/cares/cares
mkdir -p cmake/build
cd cmake/build
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX=${TMP_INSTALL} -DCARES_STATIC=ON -DCARES_SHARED=OFF -DCARES_STATIC_PIC=ON ../..
CPU_CORES=8
make -j${CPU_CORES} install
cd ../../../../..
rm -rf third_party/cares/cares  # wipe out to prevent influencing the grpc build

# 使用 module 模式：gRPC 从 third_party 构建 protobuf，避免 Homebrew protobuf 6.x 混入
# (package+Protobuf_DIR 在 macOS 上仍可能被 Homebrew include 路径覆盖)

mkdir -p cmake/build
cd cmake/build
cmake ../.. -DgRPC_INSTALL=ON                \
            -DCMAKE_BUILD_TYPE=RelWithDebInfo	\
            -DgRPC_BUILD_TESTS=OFF           \
            -DgRPC_PROTOBUF_PROVIDER=module   \
            -DgRPC_ZLIB_PROVIDER=package     \
            -DgRPC_CARES_PROVIDER=package     \
            -DgRPC_SSL_PROVIDER=package       \
            -DOPENSSL_ROOT_DIR=${OPENSSL_DIR} \
            -DOPENSSL_INCLUDE_DIR=${OPENSSL_DIR}/include \
            -DCMAKE_PREFIX_PATH=${TMP_INSTALL}:${OPENSSL_DIR} \
            -DCMAKE_INSTALL_PREFIX=${TMP_INSTALL} \
            -DCMAKE_CXX_STANDARD=14 \
            -DCMAKE_CXX_FLAGS="-Wno-deprecated-builtins -Wno-deprecated-declarations" \
            -DCMAKE_C_FLAGS="-Wno-deprecated-builtins -Wno-deprecated-declarations" \
            -DBUILD_SHARED_LIBS=OFF
make -j${CPU_CORES} install

mv $TMP_INSTALL/lib $TMP_INSTALL/grpc_lib
# mv $TMP_INSTALL/lib64 $TMP_INSTALL/grpc_lib64
mkdir -p $TMP_INSTALL/lib/grpc
# mkdir -p $TMP_INSTALL/lib64/grpc
cp -r $TMP_INSTALL/grpc_lib/* $TMP_INSTALL/lib/grpc
# cp -r $TMP_INSTALL/grpc_lib64/* $TMP_INSTALL/lib64/grpc
rm -rf $TMP_INSTALL/grpc_lib
# rm -rf $TMP_INSTALL/grpc_lib64

# copy install file
cp -r $TMP_INSTALL/* $TOP_DIR

# build package
echo "[BUILD] build tarball......"
cd $CUR_DIR/.pkg_build/
tar -zcvf ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ./usr
mv ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ${CUR_DIR}

