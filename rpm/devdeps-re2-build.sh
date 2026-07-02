#!/bin/bash
# Build devdeps-re2 RPM.
# RE2 depends on Abseil 20250814.1 or newer.
# Requires devdeps-abseil-cpp >= 20250814.1 to be installed first.

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-re2"}
VERSION=${3:-"2025-08-12"}
RELEASE=${4:-"1"}

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

# check re2 source code (re-download if file is empty/corrupted)
# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/re2-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download ${PROJECT_NAME} source code"
    wget https://hk.gh-proxy.org/https://github.com/google/re2/archive/refs/tags/${VERSION}.tar.gz -O $ROOT_DIR/re2-${VERSION}.tar.gz --no-check-certificate
fi

ID=$(grep -Po '(?<=^ID=).*' /etc/os-release | tr -d '"')
arch=`uname -p`
if [ x"${arch}" == x"loongarch64" ]; then
    yum install -y gcc cmake
    yum install -y ${loong_deps_url}/devdeps-abseil-cpp-20250814.1-20260630.an8.loongarch64.rpm
elif [[ "${ID}"x == "alinux"x ]]; then
    wget http://mirrors.aliyun.com/oceanbase/OceanBaseAlinux.repo -P /etc/yum.repos.d/
    yum install -y obdevtools-gcc9-9.3.0
    yum install -y obdevtools-cmake-3.22.1
    yum install -y devdeps-abseil-cpp-20250814.1
else
    os_release=`grep -Po '(?<=release )\d' /etc/redhat-release`
    arch=`uname -p`
    dep_pkgs=(obdevtools-gcc9-9.3.0-52022092914.el obdevtools-cmake-3.22.1-22022100417.el devdeps-abseil-cpp-20250814.1-42026041611.el)
 
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
if [ x"${arch}" == x"loongarch64" ]; then
    export TOOLS_DIR=/usr
fi
export DEP_DIR=/usr/local/oceanbase/deps/devel
export ABSL_DIR=$DEP_DIR/lib64/cmake/absl/

export PATH=$TOOLS_DIR/bin:$PATH
export LD_LIBRARY_PATH=$TOOLS_DIR/lib:$TOOLS_DIR/lib64:$LD_LIBRARY_PATH
export CC=$TOOLS_DIR/bin/gcc
export CXX=$TOOLS_DIR/bin/g++

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE
