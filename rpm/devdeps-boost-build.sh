#!/bin/bash
set -e

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-boost"}
VERSION=${3:-"1.92.0"}
RELEASE=${4:-"1"}
TOP_DIR=$CUR_DIR/.rpm_build
# Use the 1.92.0.beta1 tarball temporarily: boost 1.91.0 bundles b2 engine 5.4.2,
# which crashes at startup on loongarch64 -- OSPLAT expands to an empty string and
# var_defines() uses find('=') == npos as a length, throwing std::length_error
# (upstream bfgroup/b2#534). The fix (bfgroup/b2#535) is in b2 >= 5.5.0, first
# bundled by boost 1.92.0.beta1. Drop the _b1 suffix once formal 1.92.0 is out.
BOOST_SOURCE_DIR=boost_${VERSION//./_}
SOURCE_ARCHIVE=${BOOST_SOURCE_DIR}_b1.tar.bz2
SOURCE_SHA256=11f8f032a73cfd91899f170341578cabc040c4473e95a056cdc919c90778fa05

# download source code
if [[ ! -f "$ROOT_DIR/$SOURCE_ARCHIVE" ]]; then
    echo "Download source code"
    # beta tarballs are only on archives.boost.io (sourceforge does not mirror betas)
    wget "https://archives.boost.io/beta/${VERSION}.beta1/source/$SOURCE_ARCHIVE" \
        -O "$ROOT_DIR/$SOURCE_ARCHIVE" --no-check-certificate
fi
echo "$SOURCE_SHA256  $ROOT_DIR/$SOURCE_ARCHIVE" | sha256sum --check -


# set env variables
export PROJECT_NAME
export VERSION
export RELEASE
export BOOST_SOURCE_DIR
export SOURCE_ARCHIVE

# prepare rpm build dirs
rm -rf $TOP_DIR
mkdir -p $TOP_DIR/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

arch=`uname -p`
ID=$(grep -Po '(?<=^ID=).*' /etc/os-release | tr -d '"')

if [ x"${arch}" == x"loongarch64" ]; then
    export TOOLS_DIR=/usr
elif [[ "${ID}"x == "alinux"x ]]; then
    wget http://mirrors.aliyun.com/oceanbase/OceanBaseAlinux.repo -P /etc/yum.repos.d/
    yum install -y obdevtools-gcc9-9.3.0
    export TOOLS_DIR=/usr/local/oceanbase/devtools
else
    os_release=`grep -Po '(?<=release )\d' /etc/redhat-release`
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
