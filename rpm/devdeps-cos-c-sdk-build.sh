#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/../
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"devdeps-cos-c-sdk"}
VERSION=${3:-"5.0.16"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/cos-c-sdk-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    cd $ROOT_DIR
    git clone https://github.com/tencentyun/cos-c-sdk-v5.git cos-c-sdk-$VERSION
    cd cos-c-sdk-$VERSION
    git checkout v$VERSION
    git apply ../patch/cos_diff.patch
    cd $ROOT_DIR
    tar -zcvf cos-c-sdk-$VERSION.tar.gz cos-c-sdk-$VERSION
fi

# prepare building environment
# please prepare environment yourself if the following solution does not work for you.
# depends on cmake(suggest 2.6.0 or higher)
wget http://mirrors.aliyun.com/oceanbase/OceanBase.repo -P /etc/yum.repos.d/
yum install obdevtools-cmake-3.22.1 -y

# depends on libcurl(suggest 7.32.0 or higher)
wget --no-check-certificate https://curl.se/download/curl-8.1.2.tar.gz -O curl-8.1.2.tar.gz
tar -zxvf curl-8.1.2.tar.gz

# depends on expat
wget --no-check-certificate https://sourceforge.net/projects/expat/files/expat/2.5.0/expat-2.5.0.tar.gz/download -O expat-2.5.0.tar.gz
tar -zxvf expat-2.5.0.tar.gz

# depends on apr(suggest 1.5.2 or higher)
wget --no-check-certificate https://dlcdn.apache.org//apr/apr-1.7.4.tar.gz -O apr-1.7.4.tar.gz
tar -zxvf apr-1.7.4.tar.gz

# depends on apr(suggest 1.5.2 or higher)
wget --no-check-certificate https://dlcdn.apache.org/apr/apr-util-1.6.3.tar.gz -O apr-util-1.6.3.tar.gz
tar -zxvf apr-util-1.6.3.tar.gz

#depends on minixml
wget https://github.com/michaelrsweet/mxml/releases/download/v3.3/mxml-3.3.tar.gz -O mxml-3.3.tar.gz
tar -zxvf mxml-3.3.tar.gz

export PATH=/usr/local/oceanbase/devtools/bin:$PATH

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE