#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-hyperscan"}
VERSION=${3:-"5.4.2"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/hyperscan-v5.4.2.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    wget https://codeload.github.com/intel/hyperscan/tar.gz/refs/tags/v5.4.2 -O $ROOT_DIR/hyperscan-5.4.2.tar.gz --no-check-certificate
fi

# download boost
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/boost_1_84_0.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download boost library"
    wget https://boostorg.jfrog.io/artifactory/main/release/1.84.0/source/boost_1_84_0.tar.gz -O $ROOT_DIR/boost_1_84_0.tar.gz --no-check-certificate
fi

# download ragel
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/rage-7.0.4.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download ragel source code"
    wget  http://www.colm.net/files/ragel/ragel-6.10.tar.gz -O $ROOT_DIR/ragel-6.10.tar.gz --no-check-certificate
fi

os_release=`grep -Po '(?<=release )\d' /etc/redhat-release`
arch=`uname -p`

# build dependenciescd
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
    echo "start to download pkg from "$deps_url
    wget $deps_url/$pkg -O $pkg_dir/$TEMP
    if [[ $? == 0 ]]; then
        mv -f $pkg_dir/$TEMP $pkg_dir/$pkg
    fi
    (cd $target_dir_3rd && rpm2cpio $pkg_dir/$pkg | cpio -di -u --quiet)
done

export TOOLS_DIR=$target_dir_3rd/usr/local/oceanbase/devtools
export DEP_DIR=$target_dir_3rd/usr/local/oceanbase/deps/devel


cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE
