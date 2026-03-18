#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-sqlite"}
VERSION=${3:-"3.38.1"}
RELEASE=${4:-"1"}

export CC=/usr/bin/clang
export CXX=/usr/bin/clang++

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

bash $CUR_DIR/$PROJECT_NAME-$VERSION.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE