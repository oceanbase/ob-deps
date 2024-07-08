#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-roaringbitmap-croaring"}
VERSION=${3:-"3.0.0"}
RELEASE=${4:-"0"}
 
# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/CRoaring-3.0.0.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    wget https://github.com/RoaringBitmap/CRoaring/archive/refs/tags/v3.0.0.tar.gz -O $ROOT_DIR/CRoaring-3.0.0.tar.gz
fi

# prepare building environment
OS_RELEASE=$(grep -Po '(?<=release )\d' /etc/redhat-release)
if [ "$(uname -m)" == "ppc64le" ];then
    echo "Now install obdevtools-cmake and obdevtools-gcc manually!"
else
    wget http://mirrors.aliyun.com/oceanbase/OceanBase.repo -P /etc/yum.repos.d/
    yum install obdevtools-cmake-3.22.1 -y
    yum install obdevtools-gcc9-9.3.0 -y
fi

export PATH=/usr/local/oceanbase/devtools/bin:$PATH

ln -sf /usr/local/oceanbase/devtools/bin/g++  /usr/bin/c++
ln -sf /usr/local/oceanbase/devtools/bin/gcc  /usr/bin/cc

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE