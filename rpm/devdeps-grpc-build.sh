#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/../
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"devdeps-grpc"}
VERSION=${3:-"1.20.1"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/grpc-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    cd $ROOT_DIR
    git clone https://github.com/grpc/grpc.git -b v1.20.1 --depth 1 grpc-$VERSION
    cd grpc-$VERSION
    git submodule update --init --recursive
    cd $ROOT_DIR
    tar -zcvf grpc-$VERSION.tar.gz grpc-$VERSION
fi

# prepare building environment
# please prepare environment yourself if the following solution does not work for you.

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE