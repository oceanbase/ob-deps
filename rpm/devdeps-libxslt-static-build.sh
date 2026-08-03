#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-libxslt-static"}
VERSION=${3:-"1.1.34"}
RELEASE=${4:-"1"}

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/libxslt-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download libxslt source code"
    wget --no-check-certificate \
        https://download.gnome.org/sources/libxslt/$VERSION_SERIES/libxslt-$VERSION.tar.xz \
        -O $ROOT_DIR/libxslt-$VERSION.tar.xz
fi

OS_RELEASE=`grep -Po '(?<=release )\d' /etc/redhat-release`
arch=`uname -p`

setup_centos7_repo()
{
    local os_release

    os_release=$(grep -Po '(?<=PRETTY_NAME=")[^"]+' /etc/os-release | sed 's/^ *//;s/ *$//')
    echo $os_release
    if [[ "$os_release" == *'CentOS Linux 7 (Core)'* ]]; then
        wget -O /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
    elif [[ "$os_release" == *'CentOS Linux 7 (AltArch)'* ]]; then
        wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-altarch-7.repo
    else
        echo $os_release
        echo 'not 7'
    fi
}

if [[ "$arch" == "loongarch64" ]]; then
    yum install -y ${loong_deps_url}/devdeps-libxml2-2.15.3-22026073116.an8.loongarch64.rpm
if [[ "${ID}"x == "alinux"x ]]; then
    wget http://mirrors.aliyun.com/oceanbase/OceanBaseAlinux.repo -P /etc/yum.repos.d/
    yum install devdeps-libxml2-2.15.3 -y
else
    setup_centos7_repo
    wget https://mirrors.aliyun.com/oceanbase/OceanBase.repo -P /etc/yum.repos.d/
    yum install devdeps-libxml2-2.15.3 -y
fi

export DEP_DIR=$target_dir_3rd/usr/local/oceanbase/deps/devel
export LIBXML2_PREFIX=$DEP_DIR

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE
