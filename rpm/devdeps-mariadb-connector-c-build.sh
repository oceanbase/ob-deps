#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-mariadb-connector-c"}
VERSION=${3:-"3.1.12"}
RELEASE=${4:-"1"}

export CC=/usr/bin/clang
export CXX=/usr/bin/clang++

# download deps
export DEPS_PREFIX=$ROOT_DIR/usr/local/oceanbase/deps/devel

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

bash $CUR_DIR/$PROJECT_NAME-$VERSION.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE
