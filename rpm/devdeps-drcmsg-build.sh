#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_NAME=${2:-"devdeps-drcmsg"}
VERSION=${3:-"1.1"}
RELEASE=${4:-"312026052510"}
TOP_DIR=$CUR_DIR/.rpm_build

# check source code
if [[ ! -d "$ROOT_DIR/drcmsg" ]]; then
    echo "Download $PROJECT_NAME source code"
    cd $ROOT_DIR
    git clone git@code.alipay.com:oms/drcmsg.git -b 202605 --depth=20
fi

if [[ ! -d "$ROOT_DIR/drcmsg/deps/3rd/drcmsg.an8.loongarch64.deps" ]]; then
    cd $ROOT_DIR/drcmsg
    git apply $ROOT_DIR/loongarch/drcmsg.diff
    cp $ROOT_DIR/loongarch/drcmsg.an8.loongarch64.deps deps/3rd
fi

cd $ROOT_DIR/drcmsg/rpm

# set env variables
export PROJECT_NAME
export VERSION
export RELEASE

# prepare rpm build dirs
rm -rf $TOP_DIR
mkdir -p $TOP_DIR/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

rpmbuild --define "_topdir $TOP_DIR" -bb $PROJECT_NAME.spec
find $TOP_DIR/ -name "*.rpm" -exec mv {} "$CUR_DIR" 2>/dev/null \;