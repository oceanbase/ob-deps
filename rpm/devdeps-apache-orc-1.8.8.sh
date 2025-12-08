#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-apache-orc"}
VERSION=${3:-"1.8.8"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/orc-$VERSION.*[tar|gz|bz2|xz|zip]$"` ]]; then
    echo "Download ${PROJECT_NAME} source code"
    wget --no-check-certificate https://github.com/apache/orc/archive/refs/tags/rel/release-${VERSION}.tar.gz -O $ROOT_DIR/orc-${VERSION}.tar.gz
fi

# init build package env
echo "[BUILD] args: CURDIR=${CUR_DIR} PROJECT_NAME=${PROJECT_NAME} VERSION=${VERSION} RELEASE=${RELEASE}"
CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || grep -c ^processor /proc/cpuinfo)
TOP_DIR=$CUR_DIR/.pkg_build/usr/local/oceanbase/deps/devel
rm -rf $TOP_DIR && mkdir -p $TOP_DIR

export CFLAGS="-fPIC"
export CXXFLAGS="-fPIC -D_GLIBCXX_USE_CXX11_ABI=0"

# 定义函数：修复 zlib 的 zutil.h 以兼容 macOS
fix_zlib_for_macos() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Triggering zlib extraction and applying macOS fixes..."

    # 触发 zlib 解压（通过仅构建 zlib_ep）
    make zlib_ep 2>&1 | head -20 || true

    ZLIB_UTIL_H="./zlib_ep-prefix/src/zlib_ep/zutil.h"

    # 等待 zlib 解压完成（最多 60 秒）
    for i in {1..60}; do
      if [[ -f "$ZLIB_UTIL_H" ]]; then
        echo "Found zlib zutil.h, applying macOS compatibility fixes..."

        # Fix 1: 防止 OS_CODE 在 MACOS 下被重复定义
        perl -i -pe 's/^#  define OS_CODE  7$/#  ifndef OS_CODE\n#    define OS_CODE  7\n#  endif/' "$ZLIB_UTIL_H"

        # Fix 2: 移除 macOS 下 fdopen 宏定义（macOS 的 stdio.h 已有 fdopen）
        perl -i -pe 'BEGIN{undef $/;} s/#      ifndef fdopen\n#        define fdopen\(fd,mode\) NULL \/\* No fdopen\(\) \*\/\n#      endif//' "$ZLIB_UTIL_H"

        # Fix 3: 防止 OS_CODE 在 __APPLE__ 下重复定义，并在需要时 undef fdopen
        perl -i -pe 's/^#  define OS_CODE 19$/#  ifndef OS_CODE\n#    define OS_CODE 19\n#  endif\n#  ifndef Z_SOLO\n#    ifdef fdopen\n#      undef fdopen\n#    endif\n#  endif/' "$ZLIB_UTIL_H"

        echo "Applied macOS compatibility fixes to zlib zutil.h"
        break
      fi
      sleep 1
    done

    # 如果等待 60 秒还没找到文件，给提示
    if [[ ! -f "$ZLIB_UTIL_H" ]]; then
      echo "Warning: zlib zutil.h not found after waiting, fixes may not be applied"
    fi
  else
    echo "Not macOS, skipping zlib fixes."
  fi
}

# compile and install
TMP_DIR=$CUR_DIR/$PROJECT_NAME
rm -rf $TMP_DIR && mkdir -p $TMP_DIR
TMP_INSTALL=$TMP_DIR/tmp_install
rm -rf $TMP_INSTALL && mkdir -p $TMP_INSTALL
cd $TMP_DIR
tar -xf $ROOT_DIR/orc-${VERSION}.tar.gz
cd orc-rel-release-${VERSION}
cp $ROOT_DIR/cmake/devdeps-orc-ThirdpartyToolchain.cmake ./cmake_modules/ThirdpartyToolchain.cmake
mkdir -p build && cd build

cmake .. -DCMAKE_INSTALL_PREFIX=${TMP_INSTALL} \
         -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
         -DBUILD_JAVA=OFF \
         -DBUILD_CPP_TESTS=OFF \
         -DBUILD_TOOLS=OFF \
         -DSTOP_BUILD_ON_WARNING=OFF \
         -DBUILD_POSITION_INDEPENDENT_LIB=ON \
         -DBUILD_LIBHDFSPP=OFF

max_retries=3
retry_count=0
while true; do
    make -j${CPU_CORES}
    exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo "[Build] Build succeeded."
        break
    fi
    retry_count=$((retry_count+1))
    if [ $retry_count -eq 1 ]; then
        echo "[Build] set other args"
        fix_zlib_for_macos
    fi

    if [ $retry_count -ge $max_retries ]; then
        echo "[Build] Build failed after $max_retries attempts."
        break
    fi

    echo "[Build] Build failed (attempt $retry_count/$max_retries). Retrying..."
done
make install
 
# copy install file
mkdir -p $TOP_DIR/lib64
cp -r $TMP_INSTALL/lib/* $TOP_DIR/lib64
mkdir -p $TOP_DIR/include/apache-orc
cp -r $TMP_INSTALL/include/orc $TOP_DIR/include/apache-orc/

# build package
echo "[BUILD] build tarball......"
cd $CUR_DIR/.pkg_build/
tar -zcvf ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ./usr
mv ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ${CUR_DIR}
