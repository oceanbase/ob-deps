#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-hdfs-sdk"}
VERSION=${3:-"3.3.6"}
RELEASE=${4:-"1"}

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

# check source code of hadoop
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/apache-hadoop-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download apache-hadoop source code"
    wget https://github.com/apache/hadoop/archive/refs/tags/rel/release-$VERSION.tar.gz \
    -O ${ROOT_DIR}/apache-hadoop-${VERSION}.tar.gz --no-check-certificate
fi

arch=$(uname -p)

# download cmake for compiling hadoop
CMAKE_VERSION="3.22.1"
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/cmake.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download cmake source code"
    # https://github.com/Kitware/CMake/releases/download/v3.22.1/cmake-3.22.1.tar.gz
    wget https://cmake.org/files/v3.22/cmake-${CMAKE_VERSION}.tar.gz \
    -O ${ROOT_DIR}/cmake.tar.gz --no-check-certificate
fi

# Download jdk 1.8
# jdk file is downloaded from "https://adoptium.net/zh-CN/temurin/releases/"
JDK_VERSION="jdk8u432-b06"
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/OpenJDK8U-jdk.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download jdk 1.8 with arch $arch"
    if [[ "$arch" == "x86_64" ]]; then
        wget https://github.com/adoptium/temurin8-binaries/releases/download/${JDK_VERSION}/OpenJDK8U-jdk_x64_linux_hotspot_8u432b06.tar.gz \
        -O ${ROOT_DIR}/OpenJDK8U-jdk-${arch}.tar.gz --no-check-certificate
    elif [[ "$arch" == "aarch64" ]]; then
        wget https://github.com/adoptium/temurin8-binaries/releases/download/${JDK_VERSION}/OpenJDK8U-jdk_aarch64_linux_hotspot_8u432b06.tar.gz \
        -O ${ROOT_DIR}/OpenJDK8U-jdk-${arch}.tar.gz --no-check-certificate
    else
        echo "invalid arch: $arch to setup jdk 8" && exit 1
    fi
fi

# Download maven
MAVEN_VERSION="3.9.8"
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/apache-maven.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download apache-maven-3.9.8 source code"
    wget https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
    -O ${ROOT_DIR}/apache-maven.tar.gz --no-check-certificate
fi

# Download protobuf
PROTOBUF_VERSION="3.7.1"
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/protobuf.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download protobuf source code"
    wget https://github.com/protocolbuffers/protobuf/archive/refs/tags/v${PROTOBUF_VERSION}.tar.gz \
    -O ${ROOT_DIR}/protobuf.tar.gz --no-check-certificate
fi

# Download texinfo
TEXINFO_VERSION="7.1"
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/texinfo.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "download texinfo module"
    wget https://ftp.gnu.org/gnu/texinfo/texinfo-${TEXINFO_VERSION}.tar.gz \
    -O ${ROOT_DIR}/texinfo.tar.gz --no-check-certificate
fi

# Download gsasl
GSASL_VERSION="2.2.1"
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/gsasl.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "install gsasl module"
    wget https://ftp.gnu.org/gnu/gsasl/gsasl-${GSASL_VERSION}.tar.gz \
    -O ${ROOT_DIR}/gsasl.tar.gz --no-check-certificate
fi

# build gcc9 dependencies
ID=$(grep -Po '(?<=^ID=).*' /etc/os-release | tr -d '"')
yum install -y libtool
yum install -y m4

if [[ "${ID}"x == "alinux"x ]]; then
    wget http://mirrors.aliyun.com/oceanbase/OceanBaseAlinux.repo -P /etc/yum.repos.d/
    yum install obdevtools-gcc9-9.3.0 -y
else
    target_dir_3rd=${PROJECT_DIR}/deps/3rd
    pkg_dir=$target_dir_3rd/pkg
    mkdir -p $pkg_dir
    RELEASE_ID=$(grep -Po '(?<=release )\d' /etc/redhat-release)
    dep_pkgs=(obdevtools-gcc9-9.3.0-72024081318.el)
    download_base_url="https://mirrors.aliyun.com/oceanbase/development-kit/el"
 
    for dep_pkg in ${dep_pkgs[@]}
    do
        TEMP=$(mktemp -p "/" -u ".XXXX")
        deps_url=${download_base_url}/${RELEASE_ID}/${arch}
        pkg=${dep_pkg}${RELEASE_ID}.${arch}.rpm
        wget $deps_url/$pkg -O $pkg_dir/$TEMP
        if [[ $? == 0 ]]; then
            mv -f $pkg_dir/$TEMP $pkg_dir/$pkg
        fi
        (cd / && rpm2cpio $pkg_dir/$pkg | cpio -di -u --quiet)
    done
    # wget http://mirrors.aliyun.com/oceanbase/OceanBase.repo -P /etc/yum.repos.d/
    # yum install obdevtools-gcc9-9.3.0 -y
fi

export TOOLS_DIR=/usr/local/oceanbase/devtools
export PATH=$TOOLS_DIR/bin:$PATH
export LD_LIBRARY_PATH=$TOOLS_DIR/lib:$TOOLS_DIR/lib64:$LD_LIBRARY_PATH
export CC=$TOOLS_DIR/bin/gcc
export CXX=$TOOLS_DIR/bin/g++

ln -sf $TOOLS_DIR/bin/g++  /usr/bin/c++
ln -sf $TOOLS_DIR/bin/gcc  /usr/bin/cc

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE
