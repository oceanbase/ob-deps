#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-protobuf-c"}
VERSION=${3:-"1.4.1"}
RELEASE=${4:-"2"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/protobuf-all-3.20.3.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    wget https://github.com/protocolbuffers/protobuf/releases/download/v3.20.3/protobuf-all-3.20.3.tar.gz -O $ROOT_DIR/protobuf-all-3.20.3.tar.gz
fi

if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/protobuf-c-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    wget https://github.com/protobuf-c/protobuf-c/releases/download/v${VERSION}/protobuf-c-${VERSION}.tar.gz -O $ROOT_DIR/protobuf-c-$VERSION.tar.gz
fi

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE
