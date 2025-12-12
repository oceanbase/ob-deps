#!/bin/bash
CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"obdevtools-llvm"}
VERSION=${3:-"17.0.6"}
RELEASE=${4:-"1"}

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/llvm-${VERSION}.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"

    wget https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/llvm-${VERSION}.src.tar.xz -P $ROOT_DIR --no-check-certificate
    wget https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/lld-${VERSION}.src.tar.xz -P $ROOT_DIR --no-check-certificate
    # wget https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/lldb-${VERSION}.src.tar.xz -P $ROOT_DIR --no-check-certificate
    wget https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/clang-${VERSION}.src.tar.xz -P $ROOT_DIR --no-check-certificate
    wget https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/compiler-rt-${VERSION}.src.tar.xz -P $ROOT_DIR --no-check-certificate
    wget https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/libunwind-${VERSION}.src.tar.xz -P $ROOT_DIR --no-check-certificate
    wget https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/third-party-${VERSION}.src.tar.xz -P $ROOT_DIR --no-check-certificate
    wget https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}/cmake-${VERSION}.src.tar.xz -P $ROOT_DIR --no-check-certificate
fi

# prepare building environment
ID=$(grep -Po '(?<=^ID=).*' /etc/os-release | tr -d '"')
arch=`uname -p`

if [[ "${ID}"x == "alinux"x ]]; then
    wget http://mirrors.aliyun.com/oceanbase/OceanBaseAlinux.repo -P /etc/yum.repos.d/
    yum install obdevtools-cmake-3.22.1 -y
    yum install obdevtools-gcc-12.3.0 -y
else
    RELEASE_ID=$(grep -Po '(?<=release )\d' /etc/redhat-release)
    target_dir_3rd=${PROJECT_DIR}/deps/3rd
    pkg_dir=$target_dir_3rd/pkg
    mkdir -p $pkg_dir
 
    dep_pkgs=(obdevtools-cmake-3.22.1-22022100417.el obdevtools-gcc-12.3.0-32024122017.el)
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
        rpm -ivh --force $pkg_dir/$pkg
        # (cd / && rpm2cpio $pkg_dir/$pkg | cpio -di -u --quiet)
    done
fi

export PATH=/usr/local/oceanbase/devtools/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/oceanbase/devtools/lib:/usr/local/oceanbase/devtools/lib64:$LD_LIBRARY_PATH
export CC=/usr/local/oceanbase/devtools/bin/gcc
export CXX=/usr/local/oceanbase/devtools/bin/g++
export AR=/usr/local/oceanbase/devtools/bin/gcc-ar
export RANLIB=/usr/local/oceanbase/devtools/bin/gcc-ranlib

cd $CUR_DIR
PROJECT_NAME_VERSION=$PROJECT_NAME.$VERSION
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME_VERSION $VERSION $RELEASE
