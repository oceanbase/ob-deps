#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-paimon-cpp"}
VERSION=${3:-"0.1.2"}
RELEASE=${4:-"1"}

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

# check source code
PAIMON_CPP_COMMIT="c65575d63fec25890d0988de60224bd1c1baea54"
# PAIMON_CPP_ARROW_PATCH=$ROOT_DIR/patch/paimon-cpp-arrow20-fat-archive.patch
# 解决 orc timezone 卡死问题
PAIMON_CPP_ORC_TIMEZONE_PATH=$ROOT_DIR/patch/paimon-cpp-orc-timezone.patch
# 解决 Identifier.h 析构 core 的问题
PAIMON_CPP_IDENTIFIER_CORE=$ROOT_DIR/patch/paimon-cpp-identifier-core.patch
# 加速镜像下载
PAIMON_CPP_DOWNLOAD_MIRROR_PATH=$ROOT_DIR/patch/paimon-cpp-download-mirror.patch
if [[ ! -d $ROOT_DIR/paimon-cpp-$VERSION ]]; then
    echo "Clone ${PROJECT_NAME} source code from master"
    git clone https://github.com/alibaba/paimon-cpp.git $ROOT_DIR/paimon-cpp-$VERSION
    cd $ROOT_DIR/paimon-cpp-$VERSION
    git checkout $PAIMON_CPP_COMMIT

    # no need to patch arrow now
    # echo "Apply patch: $PAIMON_CPP_ARROW_PATCH"
    # git apply $PAIMON_CPP_ARROW_PATCH

    echo "Apply patch: $PAIMON_CPP_ORC_TIMEZONE_PATH"
    git apply $PAIMON_CPP_ORC_TIMEZONE_PATH

    echo "Apply patch: $PAIMON_CPP_IDENTIFIER_CORE"
    git apply $PAIMON_CPP_IDENTIFIER_CORE
    
    echo "Apply patch: $PAIMON_CPP_DOWNLOAD_MIRROR_PATH"
    git apply $PAIMON_CPP_DOWNLOAD_MIRROR_PATH
    cd -
fi
# Create tarball for rpmbuild
if [[ ! -f $ROOT_DIR/paimon-cpp-$VERSION.tar.gz ]]; then
    cd $ROOT_DIR
    tar czf paimon-cpp-$VERSION.tar.gz paimon-cpp-$VERSION
    cd -
fi

ID=$(grep -Po '(?<=^ID=).*' /etc/os-release | tr -d '"')

if [[ "${ID}"x == "alinux"x ]]; then
    wget http://mirrors.aliyun.com/oceanbase/OceanBaseAlinux.repo -P /etc/yum.repos.d/
    yum install -y obdevtools-gcc9-9.3.0
    yum install -y obdevtools-cmake-3.30.3
    yum install -y obdevtools-binutils-2.30
else
    os_release=`grep -Po '(?<=release )\d' /etc/redhat-release`
    arch=`uname -p`
    dep_pkgs=(obdevtools-gcc9-9.3.0-52022092914.el obdevtools-cmake-3.30.3-62025060510.el obdevtools-binutils-2.30-12022100413.el)
 
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

export TOOLS_DIR=/usr/local/oceanbase/devtools
export PATH=$TOOLS_DIR/bin:$PATH
export LD_LIBRARY_PATH=$TOOLS_DIR/lib:$TOOLS_DIR/lib64:$LD_LIBRARY_PATH
export CC=$TOOLS_DIR/bin/gcc
export CXX=$TOOLS_DIR/bin/g++

export ABI_FLAG=$([[ "${CXX_ABI}" == "1" ]] && echo "-abiv1" || echo "")
export ABI_CXXFLAGS=$([[ "${CXX_ABI}" == "1" ]] && echo "-D_GLIBCXX_USE_CXX11_ABI=1" || echo "-D_GLIBCXX_USE_CXX11_ABI=0")

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE
