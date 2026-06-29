#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
source "$CUR_DIR/abi-env.sh"
ROOT_DIR=$CUR_DIR/../
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"devdeps-grpc"}
VERSION=${3:-"1.46.7"}
RELEASE=${4:-"1"}

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/grpc-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    cd $ROOT_DIR
    git clone https://gh-proxy.org/https://github.com/grpc/grpc.git -b v${VERSION} --depth 1 grpc-$VERSION
    cd grpc-$VERSION
    git submodule update --init --recursive --depth=1
    cd $ROOT_DIR
    tar -zcvf grpc-$VERSION.tar.gz grpc-$VERSION
fi

# prepare building environment
# please prepare environment yourself if the following solution does not work for you.
ID=$(grep -Po '(?<=^ID=).*' /etc/os-release | tr -d '"')
arch=`uname -p`

if [[ "${ID}"x == "alinux"x ]]; then
    wget http://mirrors.aliyun.com/oceanbase/OceanBaseAlinux.repo -P /etc/yum.repos.d/
    yum install obdevtools-cmake-3.22.1 -y
    yum install obdevtools-gcc9-9.3.0 -y
    yum install -y devdeps-openssl-static-1.1.1u
    yum install -y devdeps-abseil-cpp-20250814.1
    yum install -y devdeps-protobuf-3.19.5
    yum install -y devdeps-re2-20250812
else
    wget https://mirrors.aliyun.com/oceanbase/OceanBase.repo -P /etc/yum.repos.d/
    yum install obdevtools-cmake-3.22.1 -y
    yum install obdevtools-gcc9-9.3.0 -y
    yum install -y devdeps-openssl-static-1.1.1u
    yum install -y devdeps-abseil-cpp-20250814.1
    yum install -y devdeps-protobuf-3.19.5
    yum install -y devdeps-re2-20250812
fi

export PATH=/usr/local/oceanbase/devtools/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/oceanbase/devtools/lib:/usr/local/oceanbase/devtools/lib64:$LD_LIBRARY_PATH
export DEPS_DIR=/usr/local/oceanbase/deps/devel
export DEVTOOLS_DIR=/usr/local/oceanbase/devtools
export CC=$DEVTOOLS_DIR/bin/gcc
export CXX=$DEVTOOLS_DIR/bin/g++

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME-$VERSION $VERSION $RELEASE
