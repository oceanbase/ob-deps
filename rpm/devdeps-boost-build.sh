#!/bin/bash
CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-boost"}
VERSION=${3:-"1.74.0"}
RELEASE=${4:-"1"}
TOP_DIR=$CUR_DIR/.rpm_build

# download source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/boost_1_74_0.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    wget https://boostorg.jfrog.io/artifactory/main/release/1.74.0/source/boost_1_74_0.tar.bz2 -O $ROOT_DIR/boost_1_74_0.tar.bz2 --no-check-certificate
fi

# set env variables
export PROJECT_NAME
export VERSION
export RELEASE

# prepare rpm build dirs
rm -rf $TOP_DIR
mkdir -p $TOP_DIR/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

os_release=`grep -Po '(?<=release )\d' /etc/redhat-release`
arch=`uname -p`

target_dir_3rd=${PROJECT_DIR}/deps/3rd
pkg_dir=$target_dir_3rd/pkg
mkdir -p $pkg_dir
TEMP=$(mktemp -p "/" -u ".XXXX")
pkg=obdevtools-gcc9-9.3.0-52022092914.el${os_release}.${arch}.rpm
deps_url=https://mirrors.aliyun.com/oceanbase/development-kit/el/${os_release}/${arch}
wget $deps_url/$pkg -O $pkg_dir/$TEMP
if [[ $? == 0 ]]; then
    mv -f $pkg_dir/$TEMP $pkg_dir/$pkg
fi
(cd $target_dir_3rd && rpm2cpio $pkg_dir/$pkg | cpio -di -u --quiet)
export TOOLS_DIR=$target_dir_3rd/usr/local/oceanbase/devtools

rpmbuild --define "_topdir $TOP_DIR" -bb $PROJECT_NAME.spec
find $TOP_DIR/ -name "*.rpm" -exec mv {} . 2>/dev/null \;