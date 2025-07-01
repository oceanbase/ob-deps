#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-apache-thrift"}
VERSION=${3:-"0.16.0"}
RELEASE=${4:-"1"}

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

# check source code of apache thrift
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/thrift-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download apache-thrift source code"
    wget https://archive.apache.org/dist/thrift/$VERSION/thrift-$VERSION.tar.gz \
    -O ${ROOT_DIR}/thrift-${VERSION}.tar.gz --no-check-certificate
fi

if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/boost_1_74_0.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download boost_1_74_0 source code"
    wget https://archives.boost.io/release/$VERSION/source/boost_1_74_0.tar.bz2 -O $CUR_DIR/boost_1_74_0.tar.bz2 --no-check-certificate
fi

arch=$(uname -p)

# build gcc9 dependencies
ID=$(grep -Po '(?<=^ID=).*' /etc/os-release | tr -d '"')

if [[ "${ID}"x == "alinux"x ]]; then
    wget http://mirrors.aliyun.com/oceanbase/OceanBaseAlinux.repo -P /etc/yum.repos.d/
else
    wget http://mirrors.aliyun.com/oceanbase/OceanBase.repo -P /etc/yum.repos.d/
fi

yum install obdevtools-gcc9-9.3.0 -y
export TOOLS_DIR=/usr/local/oceanbase/devtools
export PATH=$TOOLS_DIR/bin:$PATH
export LD_LIBRARY_PATH=$TOOLS_DIR/lib:$TOOLS_DIR/lib64:$LD_LIBRARY_PATH
export CC=$TOOLS_DIR/bin/gcc
export CXX=$TOOLS_DIR/bin/g++

ln -sf $TOOLS_DIR/bin/g++  /usr/bin/c++
ln -sf $TOOLS_DIR/bin/gcc  /usr/bin/cc

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE
