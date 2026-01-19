#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"obdevtools-llvm"}
VERSION=${3:-"17.0.6"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/llvm-${VERSION}.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download ${PROJECT_NAME} source code"
    wget https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/llvm-${VERSION}.src.tar.xz -P $ROOT_DIR --no-check-certificate
    wget https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/bolt-${VERSION}.src.tar.xz -P $ROOT_DIR --no-check-certificate
    wget https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/lld-${VERSION}.src.tar.xz -P $ROOT_DIR --no-check-certificate
    wget https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/lldb-${VERSION}.src.tar.xz -P $ROOT_DIR --no-check-certificate
    wget https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/clang-${VERSION}.src.tar.xz -P $ROOT_DIR --no-check-certificate
    wget https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/compiler-rt-${VERSION}.src.tar.xz -P $ROOT_DIR --no-check-certificate
    wget https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/libunwind-${VERSION}.src.tar.xz -P $ROOT_DIR --no-check-certificate
    wget https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/third-party-${VERSION}.src.tar.xz -P $ROOT_DIR --no-check-certificate
    wget https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/cmake-${VERSION}.src.tar.xz -P $ROOT_DIR --no-check-certificate
fi

# init build package env
echo "[BUILD] args: CURDIR=${CUR_DIR} PROJECT_NAME=${PROJECT_NAME} VERSION=${VERSION} RELEASE=${RELEASE}"
CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || grep -c ^processor /proc/cpuinfo)
rm -rf $CUR_DIR/.pkg_build
TOP_DIR=$CUR_DIR/.pkg_build/usr/local/oceanbase/devtools
rm -rf $TOP_DIR && mkdir -p $TOP_DIR

# compile and install
TMP_DIR=$CUR_DIR/$PROJECT_NAME
rm -rf $TMP_DIR && mkdir -p $TMP_DIR
TMP_INSTALL=$TMP_DIR/tmp_install
rm -rf $TMP_INSTALL && mkdir -p $TMP_INSTALL
cd $TMP_DIR

# prep
mkdir -p llvm_src_dir && cd llvm_src_dir
tar -xf $ROOT_DIR/clang-${VERSION}.src.tar.xz
tar -xf $ROOT_DIR/bolt-${VERSION}.src.tar.xz
tar -xf $ROOT_DIR/cmake-${VERSION}.src.tar.xz
tar -xf $ROOT_DIR/compiler-rt-${VERSION}.src.tar.xz
tar -xf $ROOT_DIR/libunwind-${VERSION}.src.tar.xz
tar -xf $ROOT_DIR/lld-${VERSION}.src.tar.xz
tar -xf $ROOT_DIR/lldb-${VERSION}.src.tar.xz
tar -xf $ROOT_DIR/llvm-${VERSION}.src.tar.xz
tar -xf $ROOT_DIR/third-party-${VERSION}.src.tar.xz

mv clang-${VERSION}.src clang
mv bolt-${VERSION}.src bolt
mv cmake-${VERSION}.src cmake
mv compiler-rt-${VERSION}.src compiler-rt
mv libunwind-${VERSION}.src libunwind
mv lld-${VERSION}.src lld
mv lldb-${VERSION}.src lldb
mv llvm-${VERSION}.src llvm
mv third-party-${VERSION}.src third-party

cp ${ROOT_DIR}/patch/fix-outline-atomics.patch ./
patch -p1 < fix-outline-atomics.patch

# build Release or RelWithDebInfo version
rm -rf build-rpm && mkdir -p build-rpm
cd build-rpm

cmake ../llvm  \
    -DCMAKE_INSTALL_PREFIX=${TMP_INSTALL} \
    -DLLVM_TARGETS_TO_BUILD="AArch64;X86" \
    -DLLVM_ENABLE_RTTI=ON \
    -DLLVM_ENABLE_EH=ON \
    -DLLVM_ENABLE_DUMP=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_PROJECTS='clang;compiler-rt;lld;bolt' \
    -DCOMPILER_RT_EXCLUDE_ATOMIC_BUILTIN=ON \
    -DDARWIN_osx_SKIP_CC_KEXT=ON \
    -DCOMPILER_RT_ENABLE_IOS=OFF \
    -DCOMPILER_RT_ENABLE_WATCHOS=OFF \
    -DCOMPILER_RT_ENABLE_TVOS=OFF \
    -G 'Unix Makefiles'

make -j${CPU_CORES}
make install

# copy install file
cp -r ${TMP_INSTALL}/* $TOP_DIR/
cd $TOP_DIR/bin
ln -sf clang-17 clang++-17

# build package
echo "[BUILD] build tarball......"
cd $CUR_DIR/.pkg_build/
tar -zcvf ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ./usr
mv ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ${CUR_DIR}