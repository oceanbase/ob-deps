#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/../
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"devdeps-libunwind-static"}
VERSION=${3:-"1.6.2"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/libunwind-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    wget https://github.com/libunwind/libunwind/releases/download/v1.6.2/libunwind-1.6.2.tar.gz -P $ROOT_DIR
fi

# prepare building environment
# please prepare environment yourself if the following solution does not work for you.
wget https://mirrors.aliyun.com/oceanbase/OceanBase.repo -P /etc/yum.repos.d/
yum install obdevtools-gcc-5.2.0 -y
export PATH=/usr/local/oceanbase/devtools/bin:$PATH

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE
