#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-s2geometry"}
VERSION=${3:-"0.10.0"}
RELEASE=${4:-"1"}

export CC=/usr/bin/clang
export CXX=/usr/bin/clang++

# download deps
export DEPS_PREFIX=$ROOT_DIR/usr/local/oceanbase/deps/devel
cd $ROOT_DIR
tar -xf $CUR_DIR/devdeps-abseil-cpp-20211102.0-20260126.tar.gz
cd $CUR_DIR
export ABSL_DIR=$DEPS_PREFIX/lib/cmake/absl/

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

bash $CUR_DIR/$PROJECT_NAME-$VERSION.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE
