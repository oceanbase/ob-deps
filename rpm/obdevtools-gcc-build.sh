#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/../
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"obdevtools-gcc"}
VERSION=${3:-"5.2.0"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/gcc-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    wget https://mirrors.aliyun.com/gnu/gcc/gcc-5.2.0/gcc-5.2.0.tar.gz -P $ROOT_DIR
    wget --no-check-certificate https://gcc.gnu.org/pub/gcc/infrastructure/mpc-0.8.1.tar.gz -P $ROOT_DIR
    wget --no-check-certificate https://gcc.gnu.org/pub/gcc/infrastructure/mpfr-2.4.2.tar.bz2 -P $ROOT_DIR
    wget --no-check-certificate https://gcc.gnu.org/pub/gcc/infrastructure/isl-0.14.tar.bz2 -P $ROOT_DIR
    wget --no-check-certificate https://gcc.gnu.org/pub/gcc/infrastructure/gmp-4.3.2.tar.bz2 -P $ROOT_DIR
fi

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE