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

if [ x"${arch}" == x"loongarch64" ]; then
    yum install -y obdevtools-cmake-3.30.3
    yum install -y obdevtools-llvm-13.0.1
else
    echo "not supported arch: ${arch}"
    exit 1
fi

yum -y remove bzip2-devel
yum -y install jemalloc jemalloc-devel

export TOOLS_DIR=/usr/local/oceanbase/devtools
export PATH=$TOOLS_DIR/bin:$PATH
export LD_LIBRARY_PATH=$TOOLS_DIR/lib:$TOOLS_DIR/lib64:$LD_LIBRARY_PATH
export OB_DEPS_PREFIX=/usr/local/oceanbase/deps/devel

export CC=$TOOLS_DIR/bin/clang
export CXX=$TOOLS_DIR/bin/clang++
export AR=$TOOLS_DIR/bin/llvm-ar
export RANLIB=$TOOLS_DIR/bin/llvm-ranlib
export NM=$TOOLS_DIR/bin/llvm-nm

echo "cmake version: $(cmake --version)"

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME-loong-$VERSION $VERSION $RELEASE
