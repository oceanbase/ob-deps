#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/../
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"devdeps-s3-cpp-sdk"}
VERSION=${3:-"1.11.156"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/aws-sdk-cpp-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    cd $ROOT_DIR
    wget https://github.com/aws/aws-sdk-cpp/archive/refs/tags/$VERSION.tar.gz \
         --no-check-certificate -O aws-sdk-cpp-$VERSION.tar.gz
fi

# depends on cmake(suggest 3.13.0 or higher)
cd $ROOT_DIR
wget http://mirrors.aliyun.com/oceanbase/OceanBase.repo -P /etc/yum.repos.d/
yum install obdevtools-cmake-3.22.1 -y
yum install zlib -y
yum install zlib-devel -y
yum install obdevtools-gcc9-9.3.0 -y
yum install devdeps-openssl-static-1.1.1u -y
yum install devdeps-libcurl-static-8.2.1 -y

export PATH=/usr/local/oceanbase/devtools/bin:$PATH

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE