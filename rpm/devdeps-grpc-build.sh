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

# prepare building environment
OS_RELEASE=$(grep -Po '(?<=release )\d' /etc/redhat-release)
arch=`uname -p`
target_dir_3rd=${PROJECT_DIR}/deps/3rd
pkg_dir=$target_dir_3rd/pkg
mkdir -p $pkg_dir

if [[ x"$OS_RELEASE" == x"3" ]]; then
   dep_pkgs=(obdevtools-gcc9-9.3.0-82024081914.al obdevtools-cmake-3.22.1-42024081614.al)
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
      rpm -ivh --force $pkg_dir/$pkg
      # (cd / && rpm2cpio $pkg_dir/$pkg | cpio -di -u --quiet)
   done
else
   dep_pkgs=(obdevtools-gcc9-9.3.0-72024081318.el obdevtools-cmake-3.22.1-22022100417.el)
   download_base_url="https://mirrors.aliyun.com/oceanbase/development-kit/el"
   os_release=$OS_RELEASE

   for dep_pkg in ${dep_pkgs[@]}
   do
      TEMP=$(mktemp -p "/" -u ".XXXX")
      deps_url=${download_base_url}/${OS_RELEASE}/${arch}
      pkg=${dep_pkg}${os_release}.${arch}.rpm
      wget $deps_url/$pkg -O $pkg_dir/$TEMP
      if [[ $? == 0 ]]; then
         mv -f $pkg_dir/$TEMP $pkg_dir/$pkg
      fi
      rpm -ivh --force $pkg_dir/$pkg
      # (cd / && rpm2cpio $pkg_dir/$pkg | cpio -di -u --quiet)
   done

   # wget http://mirrors.aliyun.com/oceanbase/OceanBase.repo -P /etc/yum.repos.d/
   # yum install obdevtools-cmake-3.22.1 -y
   # yum install obdevtools-gcc9-9.3.0 -y
fi

export PATH=/usr/local/oceanbase/devtools/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/oceanbase/devtools/lib:/usr/local/oceanbase/devtools/lib64:$LD_LIBRARY_PATH

ln -sf /usr/local/oceanbase/devtools/bin/g++  /usr/bin/c++
ln -sf /usr/local/oceanbase/devtools/bin/gcc  /usr/bin/cc

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE

