#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$CUR_DIR"}
PROJECT_NAME=${2:-"devdeps-ncurses-static"}
VERSION=${3:-"6.4"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/ncurses-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download source code"
    # wget --no-check-certificate https://invisible-mirror.net/archives/ncurses/ncurses-6.2.tar.gz -P $ROOT_DIR
    wget --no-check-certificate https://ftp.gnu.org/gnu/ncurses/ncurses-$VERSION.tar.gz -P $ROOT_DIR
fi

cd $CUR_DIR
bash $CUR_DIR/rpmbuild.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE