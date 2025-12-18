#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-kafka"}
VERSION=${3:-"2.12.1"}
RELEASE=${4:-"1"}

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/librdkafka-$VERSION.*[tar|gz|bz2|xz|zip|tgz]$"` ]]; then
    echo "Download ${PROJECT_NAME} source code"
    wget --no-check-certificate https://github.com/confluentinc/librdkafka/archive/refs/tags/v$VERSION.tar.gz -O $ROOT_DIR/librdkafka-$VERSION.tar.gz
fi

# build dependencies
ID=$(grep -Po '(?<=^ID=).*' /etc/os-release | tr -d '"')
arch=$(uname -p)

if [[ "${ID}"x == "alinux"x ]]; then
    wget http://mirrors.aliyun.com/oceanbase/OceanBaseAlinux.repo -P /etc/yum.repos.d/
else
    OS_RELEASE=$(grep -Po '(?<=PRETTY_NAME=")[^"]+' /etc/os-release | sed 's/^ *//;s/ *$//')
    echo $OS_RELEASE
    if [[ "$OS_RELEASE" == *'CentOS Linux 7 (Core)'* ]]; then
        wget -O /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
    elif [[ "$OS_RELEASE" == *'CentOS Linux 7 (AltArch)'* ]]; then
        wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-altarch-7.repo
    else
        echo $OS_RELEASE
        echo 'not 7'
    fi
    wget http://mirrors.aliyun.com/oceanbase/OceanBase.repo -P /etc/yum.repos.d/
fi

if [[ "$USE_LIBCURL" == "1" ]]; then
    yum install devdeps-libcurl-static-8.12.1 -y
fi

yum remove -y openssl-devel
yum install -y obdevtools-gcc9-9.3.0 devdeps-openssl-static-1.1.1u
export DEPS_DIR=/usr/local/oceanbase/deps/devel
export TOOLS_DIR=/usr/local/oceanbase/devtools
export PATH=$TOOLS_DIR/bin:${DEPS_DIR}/bin:$PATH
export CC=$TOOLS_DIR/bin/gcc
export CXX=$TOOLS_DIR/bin/g++

ln -sf $TOOLS_DIR/bin/g++  /usr/bin/c++
ln -sf $TOOLS_DIR/bin/gcc  /usr/bin/cc
 
cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME-$VERSION $VERSION $RELEASE
