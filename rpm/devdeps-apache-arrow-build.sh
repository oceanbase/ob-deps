#!/bin/bash
 
CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-apache-arrow"}
VERSION=${3:-"20.0.0"}
RELEASE=${4:-"1"}

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/apache-arrow-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download apache-arrow source code"
    wget https://archive.apache.org/dist/arrow/arrow-$VERSION/apache-arrow-$VERSION.tar.gz -O $ROOT_DIR/apache-arrow-$VERSION.tar.gz --no-check-certificate
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
    yum install obdevtools-cmake-3.30.3 -y
    dep_pkgs=(obdevtools-gcc9-9.3.0-152024092711.al)
    if [[ $VERSION == "20.0.0" ]]; then
        dep_pkgs=(obdevtools-gcc9-9.3.0-152024092711.al obdevtools-llvm-17.0.6-72025060300.al)
    fi
    download_base_url="https://mirrors.aliyun.com/oceanbase/development-kit/al"
    os_release=8
else
    export OS_RELEASE=$(grep -Po '(?<=PRETTY_NAME=")[^"]+' /etc/os-release | sed 's/^ *//;s/ *$//')
    echo $OS_RELEASE
    if [[ "$OS_RELEASE" == *'CentOS Linux 7 (Core)'* ]]; then
        wget -O /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
    elif [[ "$OS_RELEASE" == *'CentOS Linux 7 (AltArch)'* ]]; then
        wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-altarch-7.repo
    else
        echo $OS_RELEASE
        echo 'not 7'
    fi
    dep_pkgs=(obdevtools-gcc9-9.3.0-72024081318.el obdevtools-cmake-3.30.3-62025060510.el)
    download_base_url="https://mirrors.aliyun.com/oceanbase/development-kit/el"
    if [[ $VERSION == "20.0.0" ]]; then
       dep_pkgs=(obdevtools-gcc9-9.3.0-72024081318.el obdevtools-llvm-17.0.6-72025060300.el obdevtools-cmake-3.30.3-62025060510.el)
    fi
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

yum -y remove bzip2-devel
yum -y install jemalloc jemalloc-devel

export TOOLS_DIR=/usr/local/oceanbase/devtools
export PATH=$TOOLS_DIR/bin:$PATH
export LD_LIBRARY_PATH=$TOOLS_DIR/lib:$TOOLS_DIR/lib64:$LD_LIBRARY_PATH
if [[ $VERSION == "20.0.0" ]]; then
    export CC=$TOOLS_DIR/bin/clang
    export CXX=$TOOLS_DIR/bin/clang++
    export AR=$TOOLS_DIR/bin/llvm-ar
    export RANLIB=$TOOLS_DIR/bin/llvm-ranlib
    export NM=$TOOLS_DIR/bin/llvm-nm
else
    export CC=$TOOLS_DIR/bin/gcc
    export CXX=$TOOLS_DIR/bin/g++
fi

echo "cmake version: $(cmake --version)"

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME-$VERSION $VERSION $RELEASE
