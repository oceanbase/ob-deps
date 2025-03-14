#!/bin/bash
 
CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-apache-arrow"}
VERSION=${3:-"18.1.0"}
RELEASE=${4:-"1"}

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/apache-arrow-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download apache-arrow source code"
    wget https://archive.apache.org/dist/arrow/arrow-$VERSION/apache-arrow-$VERSION.tar.gz -O $ROOT_DIR/apache-arrow-$VERSION.tar.gz --no-check-certificate
fi
 
# build cmake source to fix ssl problem
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/cmake-3.22.1.tar.gz$"` ]]; then
    echo "Download cmake source code"
    wget https://cmake.org/files/v3.22/cmake-3.22.1.tar.gz -P $ROOT_DIR --no-check-certificate
fi

# prepare building environment
ID=$(grep -Po '(?<=^ID=).*' /etc/os-release | tr -d '"')
 
if [[ "${ID}"x == "alinux"x ]]; then
    wget http://mirrors.aliyun.com/oceanbase/OceanBaseAlinux.repo -P /etc/yum.repos.d/
    yum install obdevtools-gcc9-9.3.0 -y
else
    wget http://mirrors.aliyun.com/oceanbase/OceanBase.repo -P /etc/yum.repos.d/
    yum install obdevtools-gcc9-9.3.0 -y
fi
 
export TOOLS_DIR=/usr/local/oceanbase/devtools
export DEP_DIR=/usr/local/oceanbase/deps/devel
export LD_LIBRARY_PATH=$TOOLS_DIR/lib64/:$LD_LIBRARY_PATH
 
cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE