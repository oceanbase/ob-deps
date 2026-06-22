#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-protobuf"}
VERSION=${3:-"3.19.5"}
RELEASE=${4:-"2"}

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/protobuf-all-${VERSION}.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download protobuf source code"
    wget https://gh-proxy.org/https://github.com/protocolbuffers/protobuf/releases/download/v${VERSION}/protobuf-all-${VERSION}.tar.gz -O $ROOT_DIR/protobuf-all-${VERSION}.tar.gz --no-check-certificate
fi

# prepare building environment
ID=$(grep -Po '(?<=^ID=).*' /etc/os-release | tr -d '"')

if [[ "${ID}"x == "alinux"x ]]; then
    wget http://mirrors.aliyun.com/oceanbase/OceanBaseAlinux.repo -P /etc/yum.repos.d/
    yum install obdevtools-cmake-3.22.1 -y
    yum install obdevtools-gcc9-9.3.0 -y
else
    RELEASE_ID=$(grep -Po '(?<=release )\d' /etc/redhat-release)
    arch=`uname -p`
    target_dir_3rd=${PROJECT_DIR}/deps/3rd
    pkg_dir=$target_dir_3rd/pkg
    mkdir -p $pkg_dir

    dep_pkgs=(obdevtools-gcc9-9.3.0-72024081318.el obdevtools-cmake-3.22.1-22022100417.el)
    download_base_url="https://mirrors.aliyun.com/oceanbase/development-kit/el"

    for dep_pkg in ${dep_pkgs[@]}
    do
        TEMP=$(mktemp -p "/" -u ".XXXX")
        deps_url=${download_base_url}/${RELEASE_ID}/${arch}
        pkg=${dep_pkg}${RELEASE_ID}.${arch}.rpm
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