#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/../
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"devdeps-relaxed-rapidjson"}
VERSION=${3:-"1.0.0"}
RELEASE=${4:-"1"}
TOP_DIR=$CUR_DIR/.rpm_build

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/devdeps-relaxed-rapidjson-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
   echo "Download source code"
   wget https://github.com/Tencent/rapidjson/archive/27c3a8dc0e2c9218fe94986d249a12b5ed838f1d.zip -O $ROOT_DIR/devdeps-relaxed-rapidjson-$VERSION.zip --no-check-certificate
fi

# set env variables
export PROJECT_NAME
export VERSION
export RELEASE

# prepare rpm build dirs
rm -rf $TOP_DIR
mkdir -p $TOP_DIR/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# apply our patch
cd $ROOT_DIR
unzip $ROOT_DIR/devdeps-relaxed-rapidjson-$VERSION.zip
cd $ROOT_DIR/rapidjson-27c3a8dc0e2c9218fe94986d249a12b5ed838f1d
echo "move patch file here "$(pwd)
mv $ROOT_DIR/devdeps-relaxed-rapidjson.diff .
patch -p1 < devdeps-relaxed-rapidjson.diff

cd rpm
rpmbuild --define "_topdir $TOP_DIR" -bb $PROJECT_NAME.spec
find $TOP_DIR/ -name "*.rpm" -exec mv {} $CUR_DIR 2>/dev/null \;
