#!/bin/bash
 
CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-lz4"}
VERSION=${3:-"1.9.1"}
RELEASE=${4:-"1"}

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/lz4-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download ${PROJECT_NAME} source code"
    if [[ $VERSION == "1.7.1" ]]; then
        wget --no-check-certificate https://github.com/lz4/lz4/archive/refs/tags/r131.tar.gz -O $ROOT_DIR/lz4-$VERSION.tar.gz
    else
        wget --no-check-certificate https://github.com/lz4/lz4/archive/refs/tags/v$VERSION.tar.gz -O $ROOT_DIR/lz4-$VERSION.tar.gz
    fi
fi

# prepare building environment
ID=$(grep -Po '(?<=^ID=).*' /etc/os-release | tr -d '"')
arch=`uname -p`
os_release=`grep -Po '(?<=release )\d' /etc/redhat-release`
target_dir_3rd=${PROJECT_DIR}/deps/3rd
pkg_dir=$target_dir_3rd/pkg
mkdir -p $pkg_dir

if [[ "${ID}"x == "alinux"x ]]; then
    wget http://mirrors.aliyun.com/oceanbase/OceanBaseAlinux.repo -P /etc/yum.repos.d/
    dep_pkgs=(obdevtools-gcc9-9.3.0-152024092711.al)
    download_base_url="https://mirrors.aliyun.com/oceanbase/development-kit/al"
    os_release=8
else
    dep_pkgs=(obdevtools-gcc9-9.3.0-72024081318.el)
    download_base_url="https://mirrors.aliyun.com/oceanbase/development-kit/el"
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
    (cd / && rpm2cpio $pkg_dir/$pkg | cpio -di -u --quiet)
done

export PATH=/usr/local/oceanbase/devtools/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/oceanbase/devtools/lib:/usr/local/oceanbase/devtools/lib64:$LD_LIBRARY_PATH
 
cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME-$VERSION $VERSION $RELEASE
