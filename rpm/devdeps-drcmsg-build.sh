#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_NAME=${2:-"devdeps-drcmsg"}
VERSION=${3:-"1.1"}

# check source code
if [[ ! -d "$ROOT_DIR/drcmsg" ]]; then
    echo "Download $PROJECT_NAME source code"
    cd $ROOT_DIR
    git clone git@code.alipay.com:oms/drcmsg.git -b 202509-nono_time --depth=20
fi

if [[ ! -d "$ROOT_DIR/drcmsg/deps/3rd/drcmsg.an8.loongarch64.deps" ]]; then
    cd $ROOT_DIR/drcmsg
    git apply $ROOT_DIR/loongarch/drcmsg.diff
    cp $ROOT_DIR/loongarch/drcmsg.an8.loongarch64.deps deps/3rd
    cd $CUR_DIR
fi
SPEC_DIR=$ROOT_DIR/drcmsg/rpm

rpmbuild --define "_topdir $SPEC_DIR" -bb $PROJECT_NAME.spec
find $TOP_DIR/ -name "*.rpm" -exec mv {} . 2>/dev/null \;