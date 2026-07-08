#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/../
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"devdeps-prometheus-cpp"}
VERSION=${3:-"1.3.0"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/prometheus-cpp-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    cd $ROOT_DIR
    git clone https://gh-proxy.org/https://github.com/jupp0r/prometheus-cpp.git -b v${VERSION} --depth 1 prometheus-cpp-$VERSION
    cd prometheus-cpp-$VERSION
    git submodule update --init --recursive --depth 1
    cd $ROOT_DIR
    tar -zcf prometheus-cpp-$VERSION.tar.gz prometheus-cpp-$VERSION
fi

# prepare building environment
ID=$(grep -Po '(?<=^ID=).*' /etc/os-release | tr -d '"')
arch=`uname -p`

if [ x"${arch}" == x"loongarch64" ]; then
    yum install -y gcc cmake
elif [[ "${ID}"x == "alinux"x ]]; then
    wget http://mirrors.aliyun.com/oceanbase/OceanBaseAlinux.repo -P /etc/yum.repos.d/
    yum install obdevtools-cmake-3.22.1 -y
    yum install obdevtools-gcc9-9.3.0 -y
else
    wget http://mirrors.aliyun.com/oceanbase/OceanBase.repo -P /etc/yum.repos.d/
    yum install obdevtools-gcc9-9.3.0 -y
    RELEASE_ID=$(grep -Po '(?<=release )\d' /etc/redhat-release)
    target_dir_3rd=${PROJECT_DIR}/deps/3rd
    pkg_dir=$target_dir_3rd/pkg
    mkdir -p $pkg_dir

    dep_pkgs=(obdevtools-cmake-3.22.1-22022100417.el)
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

if [ x"${arch}" == x"loongarch64" ]; then
    export TOOLS_DIR=/usr
else
    export TOOLS_DIR=/usr/local/oceanbase/devtools
fi
export PATH=$TOOLS_DIR/bin:$PATH
export LD_LIBRARY_PATH=$TOOLS_DIR/lib:$TOOLS_DIR/lib64:$LD_LIBRARY_PATH
export CC=$TOOLS_DIR/bin/gcc
export CXX=$TOOLS_DIR/bin/g++

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE