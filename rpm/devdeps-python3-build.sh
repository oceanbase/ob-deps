#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-python3"}
VERSION=${3:-"3.13.3"}
RELEASE=${4:-"1"}

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/Python-$VERSION.*[tar|gz|bz2|xz|zip|tgz]$"` ]]; then
    echo "Download python3 source code"
    wget https://www.python.org/ftp/python/$VERSION/Python-$VERSION.tgz -O $ROOT_DIR/Python-$VERSION.tgz --no-check-certificate
fi

# build dependencies
ID=$(grep -Po '(?<=^ID=).*' /etc/os-release | tr -d '"')
arch=$(uname -p)

if [[ "${ID}"x == "alinux"x ]]; then
    wget http://mirrors.aliyun.com/oceanbase/OceanBaseAlinux.repo -P /etc/yum.repos.d/
else
    wget http://mirrors.aliyun.com/oceanbase/OceanBase.repo -P /etc/yum.repos.d/
fi

yum install obdevtools-gcc9-9.3.0 -y
export TOOLS_DIR=/usr/local/oceanbase/devtools
export PATH=$TOOLS_DIR/bin:$PATH
export CC=$TOOLS_DIR/bin/gcc
export CXX=$TOOLS_DIR/bin/g++

ln -sf $TOOLS_DIR/bin/g++  /usr/bin/c++
ln -sf $TOOLS_DIR/bin/gcc  /usr/bin/cc
 
cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE
