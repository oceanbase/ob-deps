#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-mariadb-connector-c"}
VERSION=${3:-"3.1.12"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/mariadb-connector-c-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download ${PROJECT_NAME} source code"
    wget --no-check-certificate https://github.com/mariadb-corporation/mariadb-connector-c/archive/refs/tags/v$VERSION.tar.gz -O $ROOT_DIR/mariadb-connector-c-$VERSION.tar.gz
fi

# init build package env
echo "[BUILD] args: CURDIR=${CUR_DIR} PROJECT_NAME=${PROJECT_NAME} VERSION=${VERSION} RELEASE=${RELEASE}"
CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || grep -c ^processor /proc/cpuinfo)
TOP_DIR=$CUR_DIR/.pkg_build/usr/local/oceanbase/deps/devel
rm -rf $TOP_DIR && mkdir -p $TOP_DIR

# compile and install
TMP_DIR=$CUR_DIR/$PROJECT_NAME
rm -rf $TMP_DIR && mkdir -p $TMP_DIR
TMP_INSTALL=$TMP_DIR/tmp_install
rm -rf $TMP_INSTALL && mkdir -p $TMP_INSTALL
cd $TMP_DIR
tar -xf $ROOT_DIR/mariadb-connector-c-$VERSION.tar.gz
cd mariadb-connector-c-$VERSION
#cp $ROOT_DIR/patch/devdeps-mariadb-connector-c.diff .
#patch -p1 < devdeps-mariadb-connector-c.diff

sed -i '' 's/END()/ENDIF()/g' cmake/ConnectorName.cmake
mkdir -p build && cd build

cmake .. -DCMAKE_INSTALL_PREFIX=$TMP_INSTALL \
         -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
         -DCMAKE_BUILD_TYPE=RelWithDebInfo \
         -DWITH_SSL=system \
	 -DWITH_EXTERNAL_ZLIB=ON \
         -DENABLED_LOCAL_INFILE=1 \
         -DDEFAULT_CHARSET=utf8
make -j${CPU_CORES}
make install

# copy install file
cp -r $TMP_INSTALL/lib $TMP_INSTALL/include ${TOP_DIR}/

# build package
echo "[BUILD] build tarball......"
cd $CUR_DIR/.pkg_build/
tar -zcvf ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ./usr
mv ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ${CUR_DIR}
