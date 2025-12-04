#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-openssl"}
VERSION=${3:-"1.1.1u"}
RELEASE=${4:-"1"}

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/openssl-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download ${PROJECT_NAME} source code"
    wget --no-check-certificate https://github.com/openssl/openssl/releases/download/OpenSSL_1_1_1u/openssl-$VERSION.tar.gz -O $ROOT_DIR/openssl-$VERSION.tar.gz --no-check-certificate
fi

bash $CUR_DIR/$PROJECT_NAME-$VERSION.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE
