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
bash devdeps-ncurses-static-build.sh
bash obdevtools-llvm-build.sh
bash devdeps-relaxed-rapidjson-build.sh
bash devdeps-libxml2-build.sh
bash devdeps-mxml-build.sh
bash devdeps-apr-build.sh
bash devdeps-xz-build.sh
bash devdeps-lua-build.sh
bash devdeps-oss-c-sdk-build.sh
bash devdeps-zlib-static-build.sh
bash devdeps-boost-build.sh
bash devdeps-s2geometry-build.sh
bash devdeps-icu-build.sh
bash devdeps-cos-c-sdk-build.sh



if [ ${NEED_BUILD_COMPILER} = 1 ]; then
    bash obdevtools-binutils-build.sh
    bash obdevtools-gcc9-build.sh
fi

if [ "${OS_ARCH}x" = "ppc64lex" ]; then
    ##backup local spec file first
    if ! grep 11.1.0 obdevtools-llvm.spec |grep -i version > /dev/null
    then
        scp  obdevtools-llvm.spec obdevtools-llvm.11.0.1.spec
        scp  obdevtools-llvm.11.1.0.spec obdevtools-llvm.spec
    fi
    bash obdevtools-llvm-build-11.1.0.sh

    bash devdeps-zlib-shared-build.sh

    ##backup local spec file first
    if ! grep 1.1.1u devdeps-openssl-static.spec |grep -i version > /dev/null
    then
        scp devdeps-openssl-static.spec devdeps-openssl-static.1.0.1e.spec 
        scp devdeps-openssl-static.1.1.1u.spec devdeps-openssl-static.spec
    fi
    bash devdeps-openssl-static-build.1.1.1u.sh

    bash devdeps-rocksdb-build-with-system-gcc.sh
fi


