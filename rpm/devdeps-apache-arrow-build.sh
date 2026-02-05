#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-apache-arrow"}
VERSION=${3:-"9.0.0"}
RELEASE=${4:-"1"}

if [ "$VERSION" = "20.0.0" ]; then
    echo "VERSION is 20.0.0"
    cd $ROOT_DIR
    tar -xf $CUR_DIR/obdevtools-llvm-17.0.6-20260122.tar.gz
    export DEV_TOOLS=$ROOT_DIR/usr/local/oceanbase/devtools
    export CC=${DEV_TOOLS}/bin/clang
    export CXX=${DEV_TOOLS}/bin/clang++
else
    export CC=/usr/bin/clang
    export CXX=/usr/bin/clang++
fi
# download deps
export DEPS_PREFIX=$ROOT_DIR/usr/local/oceanbase/deps/devel
export MACOS_VERSION=$(sw_vers -productVersion | awk -F. '{print $1}')

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

bash $CUR_DIR/$PROJECT_NAME-$VERSION.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE
