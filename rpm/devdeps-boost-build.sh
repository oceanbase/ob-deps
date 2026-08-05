#!/bin/bash
set -e

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-boost"}
VERSION=${3:-"1.91.0"}
RELEASE=${4:-"1"}
TOP_DIR=$CUR_DIR/.rpm_build
BOOST_SOURCE_DIR=boost_${VERSION//./_}
SOURCE_ARCHIVE=${BOOST_SOURCE_DIR}.tar.bz2
SOURCE_SHA256=de5e6b0e4913395c6bdfa90537febd9028ea4c0735d2cdb0cd9b45d5f51264f5

# download source code
if [[ ! -f "$ROOT_DIR/$SOURCE_ARCHIVE" ]]; then
    echo "Download source code"
    # archives.boost.io is slow from CN network recently, download from sourceforge temporarily
    wget "https://master.dl.sourceforge.net/project/boost/boost/$VERSION/$SOURCE_ARCHIVE" \
        -O "$ROOT_DIR/$SOURCE_ARCHIVE" --no-check-certificate || \
    wget "https://archives.boost.io/release/$VERSION/source/$SOURCE_ARCHIVE" \
        -O "$ROOT_DIR/$SOURCE_ARCHIVE" --no-check-certificate
fi
echo "$SOURCE_SHA256  $ROOT_DIR/$SOURCE_ARCHIVE" | sha256sum --check -


# set env variables
export PROJECT_NAME
export VERSION
export RELEASE
export BOOST_SOURCE_DIR

# prepare rpm build dirs
rm -rf $TOP_DIR
mkdir -p $TOP_DIR/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

os_release=`grep -Po '(?<=release )\d' /etc/redhat-release`
arch=`uname -p`
ID=$(grep -Po '(?<=^ID=).*' /etc/os-release | tr -d '"')

if [ x"${arch}" == x"loongarch64" ]; then
    export TOOLS_DIR=/usr
elif [[ "${ID}"x == "alinux"x ]]; then
    wget http://mirrors.aliyun.com/oceanbase/OceanBaseAlinux.repo -P /etc/yum.repos.d/
    yum install -y obdevtools-gcc9-9.3.0
    export TOOLS_DIR=/usr/local/oceanbase/devtools
else
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
fi

rpmbuild --define "_topdir $TOP_DIR" -bb $PROJECT_NAME.spec
find $TOP_DIR/ -name "*.rpm" -exec mv {} . 2>/dev/null \;
