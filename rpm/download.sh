#!/bin/bash

PROJECT_NAME=$1
VERSION=$2
ROOT_DIR=$3

# DOWNLOAD SOURCE CODE
cd $ROOT_DIR
git clone git@gitlab.alibaba-inc.com:ob-compile/deps_tarball.git -b $PROJECT_NAME-$VERSION --depth 1 deps_tarball
for file in deps_tarball/*.{tar,gz,bz2,xz,zip}; do
    if [ -e "$file" ]; then
        echo "cp $file to root_dir ..."
        cp "$file" "$ROOT_DIR"
    fi
done
rm -rf deps_tarball

