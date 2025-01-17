#!/bin/bash
 
CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-apache-orc"}
VERSION=${3:-"1.8.8"}
RELEASE=${4:-"1"}

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/orc-${VERSION}.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download apache-orc source code"
    wget https://github.com/apache/orc/archive/refs/tags/rel/release-${VERSION}.tar.gz -O $ROOT_DIR/orc-${VERSION}.tar.gz --no-check-certificate
    # wget https://github.com/apache/orc/archive/refs/tags/v${VERSION}.tar.gz -O $ROOT_DIR/orc-${VERSION}.tar.gz --no-check-certificate
fi
 
# build cmake source to fix ssl problem
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/cmake-3.22.1.tar.gz$"` ]]; then
    echo "Download cmake source code"
    wget https://cmake.org/files/v3.22/cmake-3.22.1.tar.gz -P $ROOT_DIR
fi
 
# build dependencies
ID=$(grep -Po '(?<=^ID=).*' /etc/os-release | tr -d '"')
arch=$(uname -p)

if [[ "${ID}"x == "alinux"x ]]; then
    wget http://mirrors.aliyun.com/oceanbase/OceanBaseAlinux.repo -P /etc/yum.repos.d/
    yum install obdevtools-gcc9-9.3.0 -y
else
    target_dir_3rd=${PROJECT_DIR}/deps/3rd
    pkg_dir=$target_dir_3rd/pkg
    mkdir -p $pkg_dir
    RELEASE_ID=$(grep -Po '(?<=release )\d' /etc/redhat-release)
    dep_pkgs=(obdevtools-gcc9-9.3.0-72024081318.el)
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
 
cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE
 
 