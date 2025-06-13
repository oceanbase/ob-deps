#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"obdevtools-gdb"}
VERSION=${3:-"13.2"}
RELEASE=${4:-"1"}

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

yum install -y expat gmp gmp-devel expat-devel

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/gdb-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    wget --no-check-certificate https://ftp.gnu.org/gnu/gdb/gdb-$VERSION.tar.xz -P $ROOT_DIR
    wget --no-check-certificate https://ftp.gnu.org/gnu/texinfo/texinfo-6.5.tar.xz -P $ROOT_DIR
fi

# build dependencies
ID=$(grep -Po '(?<=^ID=).*' /etc/os-release | tr -d '"')
tex_install=""

if [[ "${ID}"x == "alinux"x ]]; then
    wget http://mirrors.aliyun.com/oceanbase/OceanBaseAlinux.repo -P /etc/yum.repos.d/
    yum install obdevtools-gcc-12.3.0 -y
    yum install -y texinfo
else
    RELEASE_ID=$(grep -Po '(?<=release )\d' /etc/redhat-release)
    if [[ "$RELEASE_ID"x == "8"x ]]; then
        cd $ROOT_DIR
        rm -rf texinfo-6.5
        tar -xf texinfo-6.5.tar.xz
        tex_install="${ROOT_DIR}/texinfo_install"
        mkdir -p $tex_install
        cd texinfo-6.5
        ./configure --prefix=${tex_install}
        make -j${CPU_CORES}
        make install
    else
        yum install -y texinfo
    fi
    wget http://mirrors.aliyun.com/oceanbase/OceanBase.repo -P /etc/yum.repos.d/
    yum install obdevtools-gcc-12.3.0 -y
fi

export TOOLS_DIR=/usr/local/oceanbase/devtools
export PATH=$TOOLS_DIR/bin:$PATH:${tex_install}/bin
export LD_LIBRARY_PATH=$TOOLS_DIR/lib:$TOOLS_DIR/lib64:$LD_LIBRARY_PATH
export CC=$TOOLS_DIR/bin/gcc
export CXX=$TOOLS_DIR/bin/g++

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE