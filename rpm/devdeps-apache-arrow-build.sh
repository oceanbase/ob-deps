#!/bin/bash
 
CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-apache-arrow"}
VERSION=${3:-"20.0.0"}
RELEASE=${4:-"1"}

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/apache-arrow-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download apache-arrow source code"
    wget https://archive.apache.org/dist/arrow/arrow-$VERSION/apache-arrow-$VERSION.tar.gz -O $ROOT_DIR/apache-arrow-$VERSION.tar.gz --no-check-certificate
fi

# build cmake source to fix ssl problem
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/cmake-3.30.3.tar.gz$"` ]]; then
    echo "Download cmake source code"
    wget https://cmake.org/files/v3.30/cmake-3.30.3.tar.gz -P $ROOT_DIR --no-check-certificate
fi

# prepare building environment
ID=$(grep -Po '(?<=^ID=).*' /etc/os-release | tr -d '"')

if [[ "${ID}"x == "alinux"x ]]; then
    wget http://mirrors.aliyun.com/oceanbase/OceanBaseAlinux.repo -P /etc/yum.repos.d/
    if [[ $VERSION == "20.0.0" ]]; then
        yum install obdevtools-llvm-17.0.6 -y
    else
        yum install obdevtools-gcc9-9.3.0 -y
    fi
else
    os_release=`grep -Po '(?<=release )\d' /etc/redhat-release`
    arch=`uname -p`
    dep_pkgs=(obdevtools-gcc9-9.3.0-72024081318.el)
    if [[ $VERSION == "20.0.0" ]]; then
        dep_pkgs=(obdevtools-llvm-17.0.6-72025060300.el)
    fi
    target_dir_3rd=${PROJECT_DIR}/deps/3rd
    pkg_dir=$target_dir_3rd/pkg
    mkdir -p $pkg_dir
    for dep_pkg in ${dep_pkgs[@]}
    do
        TEMP=$(mktemp -p "/" -u ".XXXX")
        download_base_url="https://mirrors.aliyun.com/oceanbase/development-kit/el"
        deps_url=${download_base_url}/${os_release}/${arch}
        pkg=${dep_pkg}${os_release}.${arch}.rpm
        echo "start to download pkg from "$deps_url
        wget $deps_url/$pkg -O $pkg_dir/$TEMP
        if [[ $? == 0 ]]; then
            mv -f $pkg_dir/$TEMP $pkg_dir/$pkg
        fi
        (cd / && rpm2cpio $pkg_dir/$pkg | cpio -di -u --quiet)
    done
fi

yum -y remove bzip2-devel
yum -y install jemalloc jemalloc-devel

export TOOLS_DIR=/
export PATH=$TOOLS_DIR/bin:$PATH
export LD_LIBRARY_PATH=$TOOLS_DIR/lib:$TOOLS_DIR/lib64:$LD_LIBRARY_PATH
if [[ $VERSION == "20.0.0" ]]; then
    export CC=$TOOLS_DIR/bin/clang
    export CXX=$TOOLS_DIR/bin/clang++
    export AR=$TOOLS_DIR/bin/llvm-ar
    export RANLIB=$TOOLS_DIR/bin/llvm-ranlib
    export NM=$TOOLS_DIR/bin/llvm-nm
    export LD="${TOOLS_DIR}/bin/ld.lld"
else
    export CC=$TOOLS_DIR/bin/gcc
    export CXX=$TOOLS_DIR/bin/g++
fi

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME-$VERSION $VERSION $RELEASE
