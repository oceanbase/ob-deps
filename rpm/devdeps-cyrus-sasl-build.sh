#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-cyrus-sasl"}
VERSION=${3:-"2.1.28"}
RELEASE=${4:-"1"}

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

KRB5_VERSION=1.21.3
# check source code of apache thrift
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/krb5-$KRB5_VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download mit kerberos 5 source code"
    wget https://web.mit.edu/kerberos/dist/krb5/1.21/krb5-$KRB5_VERSION.tar.gz \
    -O ${ROOT_DIR}/krb5-${KRB5_VERSION}.tar.gz --no-check-certificate
fi

# Build kerberos should be with sasl, use Cyrus sasl to integrate.
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/cyrus-sasl-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download cyrus sasl source code"
    wget https://github.com/cyrusimap/cyrus-sasl/archive/refs/tags/cyrus-sasl-$VERSION.tar.gz \
    -O ${ROOT_DIR}/cyrus-sasl-${VERSION}.tar.gz --no-check-certificate
fi

arch=$(uname -p)

# build gcc9 dependencies
ID=$(grep -Po '(?<=^ID=).*' /etc/os-release | tr -d '"')

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
# Note: shoud export the krb5 installed library path into LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/usr/local/lib:$TOOLS_DIR/lib:$TOOLS_DIR/lib64:$LD_LIBRARY_PATH
export CC=$TOOLS_DIR/bin/gcc
export CXX=$TOOLS_DIR/bin/g++

ln -sf $TOOLS_DIR/bin/g++  /usr/bin/c++
ln -sf $TOOLS_DIR/bin/gcc  /usr/bin/cc

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE
