#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/../
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"devdeps-oss-c-sdk"}
VERSION=${3:-"3.11.2"}
RELEASE=${4:-"1"}

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/aliyun-oss-c-sdk-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
   echo "Download source code"
   wget https://github.com/aliyun/aliyun-oss-c-sdk/archive/refs/tags/$VERSION.tar.gz -O $ROOT_DIR/aliyun-oss-c-sdk-$VERSION.tar.gz --no-check-certificate
fi

# prepare building environment
ID=$(grep -Po '(?<=^ID=).*' /etc/os-release | tr -d '"')
os_release=`grep -Po '(?<=release )\d' /etc/redhat-release`
arch=`uname -p`
target_dir_3rd=${PROJECT_DIR}/deps/3rd
pkg_dir=$target_dir_3rd/pkg
mkdir -p $pkg_dir

if [[ "${ID}"x == "alinux"x ]]; then
   wget http://mirrors.aliyun.com/oceanbase/OceanBaseAlinux.repo -P /etc/yum.repos.d/
   yum install -y devdeps-libcurl-static-8.2.1
   yum install -y devdeps-apr-1.6.5

   dep_pkgs=(devdeps-mxml-3.3.1-22025092517.al)
   download_base_url="https://mirrors.aliyun.com/oceanbase/development-kit/al"
   os_release=8
else
   dep_pkgs=(devdeps-mxml-3.3.1-22025092517.el devdeps-apr-1.6.5-32022090616.el devdeps-libcurl-static-8.2.1-172023092015.el)
   download_base_url="https://mirrors.aliyun.com/oceanbase/development-kit/el"
fi

for dep_pkg in ${dep_pkgs[@]}
do
   TEMP=$(mktemp -p "/" -u ".XXXX")
   deps_url=${download_base_url}/${os_release}/${arch}
   pkg=${dep_pkg}${os_release}.${arch}.rpm
   wget $deps_url/$pkg -O $pkg_dir/$TEMP
   if [[ $? == 0 ]]; then
      mv -f $pkg_dir/$TEMP $pkg_dir/$pkg
   fi
   (cd / && rpm2cpio $pkg_dir/$pkg | cpio -di -u --quiet)
done

export DEP_PATH=/usr/local/oceanbase/deps/devel

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME-$VERSION $VERSION $RELEASE
