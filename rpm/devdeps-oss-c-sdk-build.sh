#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/../
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"devdeps-oss-c-sdk"}
VERSION=${3:-"3.9.2"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/aliyun-oss-c-sdk-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
   echo "Download source code"
   wget https://github.com/aliyun/aliyun-oss-c-sdk/archive/refs/tags/3.9.2.tar.gz -O $ROOT_DIR/aliyun-oss-c-sdk-$VERSION.tar.gz --no-check-certificate
fi

wget https://mirrors.aliyun.com/oceanbase/OceanBase.repo -P /etc/yum.repos.d/

yum install -y devdeps-mxml
yum install -y devdeps-apr

export PATH=/usr/local/oceanbase/devtools/bin:$PATH

ln -sf /usr/local/oceanbase/devtools/bin/g++  /usr/bin/c++
ln -sf /usr/local/oceanbase/devtools/bin/gcc  /usr/bin/cc

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE
