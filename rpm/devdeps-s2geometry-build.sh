#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-s2geometry"}
VERSION=${3:-"0.9.0"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/s2geometry-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    wget https://github.com/google/s2geometry/archive/refs/tags/v${VERSION}.tar.gz -O $ROOT_DIR/s2geometry-$VERSION.tar.gz
fi

os_release=`grep -Po '(?<=release )\d' /etc/redhat-release`
arch=`uname -p`

# build dependencies
dep_pkgs=(obdevtools-gcc9-9.3.0-52022092914.el obdevtools-cmake-3.22.1-22022100417.el devdeps-openssl-static-1.0.1e-12022100422.el)

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
    (cd $target_dir_3rd && rpm2cpio $pkg_dir/$pkg | cpio -di -u --quiet)
done

export TOOLS_DIR=$target_dir_3rd/usr/local/oceanbase/devtools
export DEP_DIR=$target_dir_3rd/usr/local/oceanbase/deps/devel


cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE
