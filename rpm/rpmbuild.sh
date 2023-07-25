#!/bin/bash

PROJECT_DIR=$1
PROJECT_NAME=$2
VERSION=$3
RELEASE=$4

CUR_DIR=$(dirname $(readlink -f "$0"))
TOP_DIR=$CUR_DIR/.rpm_build
echo "[BUILD] args: CURDIR=${CUR_DIR} PROJECT_NAME=${PROJECT_NAME} VERSION=${VERSION} RELEASE=${RELEASE}"
# prepare rpm build dirs
rm -rf $TOP_DIR
mkdir -p $TOP_DIR/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# build rpm
cd $CUR_DIR
export PROJECT_NAME=${PROJECT_NAME}
export VERSION=${VERSION}
export RELEASE=${RELEASE}
rpmbuild --define "_topdir $TOP_DIR" -bb $PROJECT_NAME.spec
find $TOP_DIR/ -name "*.rpm" -exec mv {} . 2>/dev/null \;