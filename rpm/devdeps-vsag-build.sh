#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-vsag"}
VERSION=${3:-"1.1.0"}
RELEASE=${4:-"1"}

export CC=/usr/bin/clang
export CXX=/usr/bin/clang++

# download deps
export DEV_TOOLS=$ROOT_DIR/usr/local/oceanbase/devtools
export PATH=${DEV_TOOLS}/bin:$PATH
export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
# cd $ROOT_DIR && cp ${ROOT_DIR}/rpm/obdevtools-llvm-17.0.6-20251212.tar.gz
# tar -xf obdevtools-llvm-17.0.6-20251212.tar.gz
# cd ${CUR_DIR}

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

bash $CUR_DIR/$PROJECT_NAME-$VERSION.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE