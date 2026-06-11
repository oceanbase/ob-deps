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
PAIMON_CPP_COMMIT="40f51484f5562cfd57a7f5a1c701e98aac5060b2"
# 解决 orc timezone 卡死问题
PAIMON_CPP_ORC_TIMEZONE_PATH=$ROOT_DIR/patch/paimon-cpp-orc-timezone.patch
# 解决 Identifier.h 析构 core 的问题
PAIMON_CPP_IDENTIFIER_CORE=$ROOT_DIR/patch/paimon-cpp-identifier-core.patch
# 加速镜像下载
PAIMON_CPP_DOWNLOAD_MIRROR_PATH=$ROOT_DIR/patch/paimon-cpp-download-mirror.patch
# 新增 paimon::GetLibraryVersion 接口，OB 加载 so 时做版本校验
PAIMON_CPP_VERSION_SYMBOL_PATH=$ROOT_DIR/patch/paimon-cpp-version-symbol.patch
if [[ ! -d $ROOT_DIR/paimon-cpp-$VERSION ]]; then
    echo "Clone ${PROJECT_NAME} source code from master"
    git clone https://gh-proxy.org/https://github.com/alibaba/paimon-cpp.git $ROOT_DIR/paimon-cpp-$VERSION
    cd $ROOT_DIR/paimon-cpp-$VERSION
    git checkout $PAIMON_CPP_COMMIT

    echo "Apply patch: $PAIMON_CPP_ORC_TIMEZONE_PATH"
    git apply $PAIMON_CPP_ORC_TIMEZONE_PATH

    echo "Apply patch: $PAIMON_CPP_IDENTIFIER_CORE"
    git apply $PAIMON_CPP_IDENTIFIER_CORE

    echo "Apply patch: $PAIMON_CPP_DOWNLOAD_MIRROR_PATH"
    git apply $PAIMON_CPP_DOWNLOAD_MIRROR_PATH

    echo "Apply patch: $PAIMON_CPP_VERSION_SYMBOL_PATH"
    git apply $PAIMON_CPP_VERSION_SYMBOL_PATH
    cd -
fi

# Create tarball for rpmbuild
if [[ ! -f $ROOT_DIR/paimon-cpp-$VERSION.tar.gz ]]; then
    cd $ROOT_DIR
    tar czf paimon-cpp-$VERSION.tar.gz paimon-cpp-$VERSION
    cd -
fi

# prepare building environment
ID=$(grep -Po '(?<=^ID=).*' /etc/os-release | tr -d '"')

if [[ "${ID}"x == "alinux"x ]]; then
    wget http://mirrors.aliyun.com/oceanbase/OceanBaseAlinux.repo -P /etc/yum.repos.d/
    yum install -y obdevtools-llvm-17.0.6
    yum install -y obdevtools-cmake-3.30.3
    yum install -y obdevtools-gcc9-9.3.0
else
    wget https://mirrors.aliyun.com/oceanbase/OceanBase.repo -P /etc/yum.repos.d/
    yum install -y obdevtools-llvm-17.0.6
    yum install -y obdevtools-cmake-3.30.3
    yum install -y obdevtools-gcc9-9.3.0
fi

export TOOLS_DIR=/usr/local/oceanbase/devtools
export PATH=$TOOLS_DIR/bin:$PATH
export LD_LIBRARY_PATH=$TOOLS_DIR/lib:$TOOLS_DIR/lib64:$LD_LIBRARY_PATH
export CC=$TOOLS_DIR/bin/clang
export CXX=$TOOLS_DIR/bin/clang++

export ABI_FLAG=$([[ "${CXX_ABI}" == "1" ]] && echo "-abiv1" || echo "")
export ABI_CXXFLAGS=$([[ "${CXX_ABI}" == "1" ]] && echo "-D_GLIBCXX_USE_CXX11_ABI=1" || echo "-D_GLIBCXX_USE_CXX11_ABI=0")

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE
