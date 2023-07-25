#!/bin/bash
set -ex
CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/../
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"obdevtools-llvm"}
VERSION=${3:-"11.0.1"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/llvm-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    wget https://github.com/llvm/llvm-project/releases/download/llvmorg-11.0.1/llvm-11.0.1.src.tar.xz -P $ROOT_DIR --no-check-certificate
    wget https://github.com/llvm/llvm-project/releases/download/llvmorg-11.0.1/lld-11.0.1.src.tar.xz -P $ROOT_DIR --no-check-certificate
    wget https://github.com/llvm/llvm-project/releases/download/llvmorg-11.0.1/clang-11.0.1.src.tar.xz -P $ROOT_DIR --no-check-certificate
    wget https://github.com/llvm/llvm-project/releases/download/llvmorg-11.0.1/compiler-rt-11.0.1.src.tar.xz -P $ROOT_DIR --no-check-certificate
fi

# prepare building environment
OS_RELEASE=$(grep -Po '(?<=release )\d' /etc/redhat-release)

wget http://mirrors.aliyun.com/oceanbase/OceanBase.repo -P /etc/yum.repos.d/
yum install obdevtools-cmake-3.22.1 -y
yum install obdevtools-gcc9-9.3.0 -y

export PATH=/usr/local/oceanbase/devtools/bin:$PATH

ln -sf /usr/local/oceanbase/devtools/bin/g++  /usr/bin/c++
ln -sf /usr/local/oceanbase/devtools/bin/gcc  /usr/bin/cc

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE
