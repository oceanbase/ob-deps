#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
source "$CUR_DIR/abi-env.sh"
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-s2geometry"}
VERSION=${3:-"0.10.0"}
RELEASE=${4:-"1"}

proxy_prefix=https://gh-proxy.com/
# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/s2geometry-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    wget ${proxy_prefix}https://github.com/google/s2geometry/archive/refs/tags/v${VERSION}.tar.gz -O $ROOT_DIR/s2geometry-$VERSION.tar.gz
fi

arch=`uname -p`
# prepare building environment
ID=$(grep -Po '(?<=^ID=).*' /etc/os-release | tr -d '"')

if [ x"${arch}" == x"loongarch64" ]; then
    yum install -y gcc babassl-ob-8.3.7 devdeps-abseil-cpp-20211102.0
elif [[ "${ID}"x == "alinux"x ]]; then
    wget http://mirrors.aliyun.com/oceanbase/OceanBaseAlinux.repo -P /etc/yum.repos.d/
    yum install -y obdevtools-gcc9-9.3.0
    yum install -y obdevtools-cmake-3.22.1
    yum install -y devdeps-openssl-static-1.1.1u
    yum install -y devdeps-abseil-cpp${ABI_FLAG}-20250814.1
else
    os_release=`grep -Po '(?<=release )\d' /etc/redhat-release`
    dep_pkgs=(obdevtools-gcc9-9.3.0-52022092914.el obdevtools-cmake-3.22.1-22022100417.el devdeps-openssl-static-1.1.1u-22023100710.el devdeps-abseil-cpp${ABI_FLAG}-20250814.1-42026041611.el)
 
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

export DEP_DIR=/usr/local/oceanbase/deps/devel
export PATH=/usr/local/oceanbase/devtools/bin:$PATH
if [ x"${arch}" == x"loongarch64" ]; then
    export BABASSL_DIR=/usr/local/babassl-ob
fi
export ABSL_DIR=$DEP_DIR/lib64/cmake/absl/
export LD_LIBRARY_PATH=/usr/local/oceanbase/devtools/lib:/usr/local/oceanbase/devtools/lib64:$LD_LIBRARY_PATH

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE
