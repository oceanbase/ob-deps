#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-libstemmer"}
VERSION=${3:-"3.0.1"}
RELEASE=${4:-"1"}

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/libstemmer-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download ${PROJECT_NAME} source code"
    wget https://gh-proxy.org/https://github.com/snowballstem/snowball/archive/refs/tags/v${VERSION}.tar.gz -O $ROOT_DIR/libstemmer-$VERSION.tar.gz
fi

ID=$(grep -Po '(?<=^ID=).*' /etc/os-release | tr -d '"')

if [[ "${ID}"x == "alinux"x ]]; then
    wget http://mirrors.aliyun.com/oceanbase/OceanBaseAlinux.repo -P /etc/yum.repos.d/
    yum install -y obdevtools-gcc9-9.3.0
    yum install -y obdevtools-cmake-3.30.3
else
    os_release=`grep -Po '(?<=release )\d' /etc/redhat-release`
    arch=`uname -p`
    dep_pkgs=(obdevtools-gcc9-9.3.0-52022092914.el obdevtools-cmake-3.30.3-62025060510.el)
 
    target_dir_3rd=${PROJECT_DIR}/deps/3rd
    pkg_dir=$target_dir_3rd/pkg
    mkdir -p $pkg_dir
    for dep_pkg in ${dep_pkgs[@]}
    do
        TEMP=$(mktemp -p "/" -u ".XXXX")
        download_base_url="https://mirrors.aliyun.com/oceanbase/development-kit/el"
        deps_url=${download_base_url}/${os_release}/${arch}
        pkg=${dep_pkg}${os_release}.${arch}.rpm
        wget $deps_url/$pkg -O $pkg_dir/$TEMP
        if [[ $? == 0 ]]; then
            mv -f $pkg_dir/$TEMP $pkg_dir/$pkg
        fi
        (cd / && rpm2cpio $pkg_dir/$pkg | cpio -di -u --quiet)
    done
fi

export TOOLS_DIR=/usr/local/oceanbase/devtools
export PATH=$TOOLS_DIR/bin:$PATH
export LD_LIBRARY_PATH=$TOOLS_DIR/lib:$TOOLS_DIR/lib64:$LD_LIBRARY_PATH
export CC=$TOOLS_DIR/bin/gcc
export CXX=$TOOLS_DIR/bin/g++

export ABI_FLAG=$([[ "${CXX_ABI}" == "1" ]] && echo "-abiv1" || echo "")
export ABI_CXXFLAGS=$([[ "${CXX_ABI}" == "1" ]] && echo "-D_GLIBCXX_USE_CXX11_ABI=1" || echo "-D_GLIBCXX_USE_CXX11_ABI=0")

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE
