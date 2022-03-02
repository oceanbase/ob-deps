#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/../
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"obdevtools-llvm"}
VERSION=${3:-"11.0.1"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/llvm-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    wget https://github.com/llvm/llvm-project/releases/download/llvmorg-11.0.1/llvm-11.0.1.src.tar.xz -P $ROOT_DIR
    wget https://github.com/llvm/llvm-project/releases/download/llvmorg-11.0.1/lld-11.0.1.src.tar.xz -P $ROOT_DIR
    wget https://github.com/llvm/llvm-project/releases/download/llvmorg-11.0.1/clang-11.0.1.src.tar.xz -P $ROOT_DIR
    wget https://github.com/llvm/llvm-project/releases/download/llvmorg-11.0.1/compiler-rt-11.0.1.src.tar.xz -P $ROOT_DIR
fi

# prepare building environment
OS_RELEASE=$(grep -Po '(?<=release )\d' /etc/redhat-release)
if [[ x"$OS_RELEASE" == x"7" ]]; then
    yum install -y centos-release-scl
    yum install -y devtoolset-9-gcc devtoolset-9-gcc-c++
    source /opt/rh/devtoolset-9/enable
elif [[ x"$OS_RELEASE" == x"8" ]]; then
    yum install -y gcc-toolset-9-gcc gcc-toolset-9-gcc-c++
    source /opt/rh/gcc-toolset-9/enable
fi
wget https://mirrors.aliyun.com/oceanbase/OceanBase.repo -P /etc/yum.repos.d/
yum install obdevtools-cmake-3.20.2 -y
export PATH=/usr/local/oceanbase/devtools/bin:$PATH

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE