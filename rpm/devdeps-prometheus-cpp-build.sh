#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/../
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"devdeps-prometheus-cpp"}
VERSION=${3:-"0.8.0"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/prometheus-cpp-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    cd $ROOT_DIR
    git clone https://github.com/jupp0r/prometheus-cpp.git -b v0.8.0 --depth 1 prometheus-cpp-$VERSION
    cd prometheus-cpp-$VERSION
    git submodule update --init
    cd $ROOT_DIR
    tar -zcvf prometheus-cpp-$VERSION.tar.gz prometheus-cpp-$VERSION
fi

# prepare building environment
# please prepare environment yourself if the following solution does not work for you.
# Please use gcc5.2 or higher version
OS_RELEASE=$(grep -Po '(?<=release )\d' /etc/redhat-release)
if [[ x"$OS_RELEASE" == x"7" ]]; then
    echo "Install gcc 8"
    yum install centos-release-scl -y
    yum install devtoolset-8 -y
    source /opt/rh/devtoolset-8/enable
fi

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE