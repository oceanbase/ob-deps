#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/../
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"devdeps-vsag"}
VERSION=${3:-"1.0.0"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/vsag-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download vsag source code"
    bash $CUR_DIR/download_code.sh $PROJECT_NAME $VERSION $ROOT_DIR
fi

OS_RELEASE=`grep -Po '(?<=release )\d' /etc/redhat-release`
arch=`uname -p`

target_dir_3rd=/
pkg_dir=$target_dir_3rd/pkg
mkdir -p $pkg_dir

if [[ x"$OS_RELEASE" == x"3" ]]; then
    dep_pkgs=(obdevtools-gcc9-9.3.0-142024091814.al obdevtools-cmake-3.22.1-112024083015.al)
    download_base_url="http://yum-test.obvos.alibaba-inc.com/oceanbase/development-kit/al"
    os_release=8
else
    dep_pkgs=(obdevtools-gcc9-9.3.0-72024081318.el obdevtools-cmake-3.22.1-22022100417.el)
    download_base_url="https://mirrors.aliyun.com/oceanbase/development-kit/el"
    os_release=$OS_RELEASE
fi

for dep_pkg in ${dep_pkgs[@]}
do
    TEMP=$(mktemp -p "/" -u ".XXXX")
    deps_url=${download_base_url}/${os_release}/${arch}
    pkg=${dep_pkg}${os_release}.${arch}.rpm
    echo "start to download pkg from "$deps_url
    wget $deps_url/$pkg -O $pkg_dir/$TEMP
    if [[ $? == 0 ]]; then
        mv -f $pkg_dir/$TEMP $pkg_dir/$pkg
    fi
    (cd $target_dir_3rd && rpm2cpio $pkg_dir/$pkg | cpio -di -u --quiet)
done

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE

