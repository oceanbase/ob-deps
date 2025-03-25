#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/../
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"devdeps-libcurl-static"}
VERSION=${3:-"8.12.1"}
RELEASE=${4:-"1"}

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/curl-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    # version =< 7.29.0
    # wget --no-check-certificate https://curl.se/download/archeology/curl-$VERSION.tar.gz -P $ROOT_DIR
    # version >= 7.30.0
    wget --no-check-certificate https://curl.se/download/curl-$VERSION.tar.gz -P $ROOT_DIR
fi

export CFLAGS="-fPIC -pie -fstack-protector-strong"
export CXXFLAGS="-fPIC -pie -fstack-protector-strong"

ID=$(grep -Po '(?<=^ID=).*' /etc/os-release | tr -d '"')
arch=$(uname -p)

if [[ "${ID}"x == "alinux"x ]]; then
    wget http://mirrors.aliyun.com/oceanbase/OceanBaseAlinux.repo -P /etc/yum.repos.d/
    yum install -y devdeps-openssl-static-1.1.1u
    if [[ "$arch" == "aarch64" ]]; then
        export CFLAGS="$CFLAGS -mno-outline-atomics"
        export CXXFLAGS="$CXXFLAGS -mno-outline-atomics"
    fi
else
    wget http://mirrors.aliyun.com/oceanbase/OceanBase.repo -P /etc/yum.repos.d/
    yum install -y devdeps-openssl-static-1.1.1u
fi

export DEP_DIR=/usr/local/oceanbase/deps/devel

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE