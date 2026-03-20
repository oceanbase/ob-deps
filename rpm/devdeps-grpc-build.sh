#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-grpc"}
VERSION=${3:-"1.46.7"}
RELEASE=${4:-"1"}

export CC=/usr/bin/clang
export CXX=/usr/bin/clang++

# download deps
# export DEV_TOOLS=$ROOT_DIR/usr/local/oceanbase/devtools
export DEPS_PREFIX=$ROOT_DIR/usr/local/oceanbase/deps/devel
export OPENSSL_DIR=$ROOT_DIR/usr/local/oceanbase/deps/devel
# 确保解压到 ROOT_DIR，使 OPENSSL_DIR 路径正确
cd "$ROOT_DIR" || exit 1
MACOS_VERSION=${MACOS_VERSION:-$(sw_vers -productVersion | awk -F. '{print $1}')}
ARCH="$(uname -m)"
# 按 macOS 主版本选择镜像路径与包名（darwin/15 与 darwin/13）
if [ "${MACOS_VERSION}" -ge 15 ]; then
  DARWIN_KIT="15"
  OPENSSL_TAR="devdeps-openssl-1.1.1u-20251204.tar.gz"
else
  DARWIN_KIT="13"
  OPENSSL_TAR="devdeps-openssl-1.1.1u-20260126.tar.gz"
fi
OPENSSL_URL="https://mirrors.aliyun.com/oceanbase/development-kit/darwin/${DARWIN_KIT}/${ARCH}/${OPENSSL_TAR}"
echo "[deps] macOS ${MACOS_VERSION} (${ARCH}) -> ${OPENSSL_URL}"
wget "${OPENSSL_URL}" -O "${OPENSSL_TAR}"
tar -xf "${OPENSSL_TAR}"

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

bash $CUR_DIR/$PROJECT_NAME-$VERSION.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE
