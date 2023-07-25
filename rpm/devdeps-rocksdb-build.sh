#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/../
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"devdeps-rocksdb"}
VERSION=${3:-"6.22.1"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/rocksdb-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    for cnt in {1..6}
    do
        echo "Download source code with retry cnt = "$cnt
        wget --no-check-certificate https://github.com/facebook/rocksdb/archive/refs/tags/v6.22.1.tar.gz -O $ROOT_DIR/rocksdb-$VERSION.tar.gz
        if [[ $? == 0 ]];then
            break
        fi
    done
fi

# prepare building environment
# please prepare environment yourself if the following solution does not work for you.
OS_RELEASE=$(grep -Po '(?<=release )\d' /etc/redhat-release)
echo "Install gcc 9"
wget http://mirrors.aliyun.com/oceanbase/OceanBase.repo -P /etc/yum.repos.d/
yum install obdevtools-gcc9-9.3.0 -y
yum install obdevtools-cmake-3.22.1 -y

export PATH=/usr/local/oceanbase/devtools/bin:$PATH

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE
