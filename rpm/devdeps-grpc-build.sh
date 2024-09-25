#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/../
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"devdeps-grpc"}
VERSION=${3:-"1.46.7"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/grpc-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    bash $CUR_DIR/download.sh $PROJECT_NAME $VERSION $ROOT_DIR
fi

# build dependencies
OS_RELEASE=`grep -Po '(?<=release )\d' /etc/redhat-release`




if [[ x"$OS_RELEASE" == x"3" ]]; then
    arch=`uname -p`
    target_dir_3rd=${PROJECT_DIR}/deps/3rd
    pkg_dir=$target_dir_3rd/pkg
    mkdir -p $pkg_dir

    dep_pkgs=(obdevtools-cmake-3.22.1-112024083015.al)
    download_base_url="http://yum-test.obvos.alibaba-inc.com/oceanbase/development-kit/al"
    os_release=8
    for dep_pkg in ${dep_pkgs[@]}
    do
        TEMP=$(mktemp -p "/" -u ".XXXX")
        deps_url=${download_base_url}/${os_release}/${arch}
        pkg=${dep_pkg}${os_release}.${arch}.rpm
        wget $deps_url/$pkg -O $pkg_dir/$TEMP
        if [[ $? == 0 ]]; then
            mv -f $pkg_dir/$TEMP $pkg_dir/$pkg
        fi
        (cd $target_dir_3rd && rpm2cpio $pkg_dir/$pkg | cpio -di -u --quiet)
    done

    # environmental parameters
    export PATH=$target_dir_3rd/usr/local/oceanbase/devtools/bin:$PATH

    ln -sf $target_dir_3rd/usr/local/oceanbase/devtools/bin/cmake  /usr/bin/cmake

else
    # prepare building environment
    # please prepare environment yourself if the following solution does not work for you.
    # depends on cmake(suggest 2.6.0 or higher)
    wget https://mirrors.aliyun.com/oceanbase/OceanBase.repo -P /etc/yum.repos.d/
    yum remove cmake -y
    yum install obdevtools-cmake-3.22.1 -y
    #wget http://yum-test.obvos.alibaba-inc.com/oceanbase/OceanBaseTest.repo -P /etc/yum.repos.d/
    #yum remove cmake -y
    #yum install cmake-3.11.4 -y
fi


cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE
