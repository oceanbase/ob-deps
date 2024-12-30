#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/../
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"devdeps-rocksdb"}
VERSION=${3:-"6.22.1"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/rocksdb-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    for cnt in {1..6}
    do
        echo "Download source code with retry cnt = "$cnt
        wget --no-check-certificate https://github.com/facebook/rocksdb/archive/refs/tags/v6.22.1.tar.gz -O $ROOT_DIR/rocksdb-$VERSION.tar.gz
        if [[ $? == 0 ]];then
            break
        fi
    done
fi

# prepare building environment
ID=$(grep -Po '(?<=^ID=).*' /etc/os-release | tr -d '"')
 
if [[ "${ID}"x == "alinux"x ]]; then
    wget http://mirrors.aliyun.com/oceanbase/OceanBaseAlinux.repo -P /etc/yum.repos.d/
    yum install -y obdevtools-gcc9-9.3.0
    yum install -y obdevtools-cmake-3.22.1
else
    os_release=`grep -Po '(?<=release )\d' /etc/redhat-release`
    arch=`uname -p`
    dep_pkgs=(obdevtools-gcc9-9.3.0-52022092914.el obdevtools-cmake-3.22.1-22022100417.el)
 
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

export PATH=/usr/local/oceanbase/devtools/bin:$PATH

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE
