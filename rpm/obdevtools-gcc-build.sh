#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"obdevtools-gcc"}
VERSION=${3:-"12.3.0"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/gcc-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    wget https://mirrors.aliyun.com/gnu/gcc/gcc-${VERSION}/gcc-${VERSION}.tar.gz -P $ROOT_DIR
    wget --no-check-certificate https://gcc.gnu.org/pub/gcc/infrastructure/mpc-1.2.1.tar.gz -P $ROOT_DIR
    wget --no-check-certificate https://gcc.gnu.org/pub/gcc/infrastructure/mpfr-4.1.0.tar.bz2 -P $ROOT_DIR
    wget --no-check-certificate https://gcc.gnu.org/pub/gcc/infrastructure/isl-0.24.tar.bz2 -P $ROOT_DIR
    wget --no-check-certificate https://gcc.gnu.org/pub/gcc/infrastructure/gmp-6.2.1.tar.bz2 -P $ROOT_DIR
fi

# prepare building environment
OS_RELEASE=$(grep -Po '(?<=release )\d' /etc/redhat-release)
if [[ x"$OS_RELEASE" == x"7" ]]; then
    yum install -y centos-release-scl
    yum install -y devtoolset-8-gcc devtoolset-8-gcc-c++
    source /opt/rh/devtoolset-8/enable
fi

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE