#!/bin/bash
 
CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-babassl-ob"}
VERSION=${3:-"8.3.7"}
RELEASE=${4:-"20260627"}

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

if [[ ! -d "$ROOT_DIR/BabaSSL" ]]; then
    echo "Download $PROJECT_NAME source code"
    git clone git@gitlab.alipay-inc.com:afe/BabaSSL.git -b BabaSSL_8_3_0-stable-zb --depth 1 "$ROOT_DIR/BabaSSL"
fi

export CC=/usr/bin/gcc
export CXX=/usr/bin/g++

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE