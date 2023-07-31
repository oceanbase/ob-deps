#!/bin/bash
set -ex

OS_ARCH="$(uname -m)"

NEED_BUILD_COMPILER=1

if [ "${OS_ARCH}x" = "sw_64x" ]; then
    NEED_BUILD_COMPILER=0
fi

bash obdevtools-cmake-build.sh
bash devdeps-openssl-static-build.sh
bash devdeps-isa-l-static-build.sh
bash devdeps-mariadb-connector-c-build.sh
bash devdeps-libunwind-static-build.sh
bash devdeps-libcurl-static-build.sh
bash devdeps-libaio-build.sh
bash devdeps-rapidjson-build.sh
bash obdevtools-ccache-build.sh
bash devdeps-rocksdb-build.sh
bash obdevtools-flex-build.sh
bash devdeps-gtest-build.sh
bash obdevtools-bison-build.sh

if [ ${NEED_BUILD_COMPILER} = 1 ]; then
    bash obdevtools-binutils-build.sh
    bash obdevtools-gcc-build.sh
fi

