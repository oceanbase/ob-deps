#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
source "$CUR_DIR/abi-env.sh"
ROOT_DIR=$CUR_DIR/../
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"devdeps-gtest"}
VERSION=${3:-"1.8.0"}
RELEASE=${4:-"1"}

proxy_prefix=https://gh-proxy.com/

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/googletest-release-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    wget ${proxy_prefix}https://github.com/google/googletest/archive/release-1.8.0.tar.gz -O $ROOT_DIR/googletest-release-$VERSION.tar.gz || exit 1
fi

# prepare compiling tools
ID=$(grep -Po '(?<=^ID=).*' /etc/os-release | tr -d '"')
if [[ "${ID}"x == "alinux"x ]]; then
  wget http://mirrors.aliyun.com/oceanbase/OceanBaseAlinux.repo -P /etc/yum.repos.d/
else
  wget http://mirrors.aliyun.com/oceanbase/OceanBase.repo -P /etc/yum.repos.d/
fi
yum install obdevtools-cmake-3.22.1 obdevtools-gcc9-9.3.0 -y --disablerepo=\* --enablerepo=oceanbase.* || exit 1

export PATH=/usr/local/oceanbase/devtools/bin:$PATH

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE
