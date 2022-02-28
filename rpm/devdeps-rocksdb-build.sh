#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/../
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"devdeps-rocksdb"}
VERSION=${3:-"6.22.1"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/rocksdb-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    wget https://github.com/facebook/rocksdb/archive/refs/tags/v6.22.1.tar.gz -O $ROOT_DIR/rocksdb-$VERSION.tar.gz
fi

# prepare building environment
# please prepare environment yourself if the following solution does not work for you.
OS_RELEASE=$(grep -Po '(?<=release )\d' /etc/redhat-release)
if [[ x"$OS_RELEASE" == x"7" ]]; then
    echo "Install gcc 8"
    yum install centos-release-scl -y
    yum install devtoolset-8 -y
    source /opt/rh/devtoolset-8/enable
fi

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE