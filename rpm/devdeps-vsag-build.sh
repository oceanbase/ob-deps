#!/bin/bash
 
CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/../
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"devdeps-vsag"}
VERSION=${3:-"1.1.0"}
RELEASE=${4:-"1"}
 
if [[ $VERSION == "1.0.0" ]]; then
  VSAG_VERSION="0.14.7"
else
  # default use newest vsag
  VSAG_VERSION="0.15.0"
fi

echo "VERSION=${VERSION} VSAG_VERSION=${VSAG_VERSION}"

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/vsag-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download vsag source code"
    for cnt in {1..6}
    do
        echo "Download source code with retry cnt = "$cnt
        wget --no-check-certificate https://github.com/antgroup/vsag/archive/refs/tags/v${VSAG_VERSION}.tar.gz -O $ROOT_DIR/vsag-$VERSION.tar.gz
	if [[ $? == 0 ]];then
            break
        fi
    done
fi

# prepare building environment
ID=$(grep -Po '(?<=^ID=).*' /etc/os-release | tr -d '"')

if [[ "${ID}"x == "alinux"x ]]; then
    wget http://mirrors.aliyun.com/oceanbase/OceanBaseAlinux.repo -P /etc/yum.repos.d/
    sed -i '6s/enabled=1/enabled=0/' /etc/yum.repos.d/OceanBaseAlinux.repo
    yum install obdevtools-gcc9-9.3.0 -y
    yum install obdevtools-cmake-3.22.1 -y
else
    os_release=`grep -Po '(?<=release )\d' /etc/redhat-release`
    arch=`uname -p`
    dep_pkgs=(obdevtools-gcc9-9.3.0-72024081318.el obdevtools-cmake-3.22.1-142025032516.el)
    target_dir_3rd=${PROJECT_DIR}/deps/3rd
    pkg_dir=$target_dir_3rd/pkg
    mkdir -p $pkg_dir
    for dep_pkg in ${dep_pkgs[@]}
    do
        TEMP=$(mktemp -p "/" -u ".XXXX")
        download_base_url="https://mirrors.aliyun.com/oceanbase/development-kit/el"
        deps_url=${download_base_url}/${os_release}/${arch}
        pkg=${dep_pkg}${os_release}.${arch}.rpm
        echo "start to download pkg from "$deps_url
        wget $deps_url/$pkg -O $pkg_dir/$TEMP
        if [[ $? == 0 ]]; then
            mv -f $pkg_dir/$TEMP $pkg_dir/$pkg
        fi
        # rpm -ivh --force $pkg_dir/$pkg
        (cd / && rpm2cpio $pkg_dir/$pkg | cpio -di -u --quiet)
    done
fi
 
export PATH=/usr/local/oceanbase/devtools/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/oceanbase/devtools/lib:/usr/local/oceanbase/devtools/lib64:$LD_LIBRARY_PATH
 
cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR ${PROJECT_NAME}.${VERSION} $VERSION $RELEASE
 
