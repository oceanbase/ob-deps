#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-vsag"}
VERSION=${3:-"1.1.0"}
RELEASE=${4:-"1"}

export CC=/usr/bin/clang
export CXX=/usr/bin/clang++

# download deps
export DEV_TOOLS=$ROOT_DIR/usr/local/oceanbase/devtools
export PATH=${DEV_TOOLS}/bin:$PATH
export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
# cd $ROOT_DIR
# tar -xf ${ROOT_DIR}/rpm/obdevtools-llvm-17.0.6-20260122.tar.gz
# cd ${CUR_DIR}

# brew install libomp lapack gcc
export MACOS_VERSION=$(sw_vers -productVersion | awk -F. '{print $1}')
if [ $MACOS_VERSION -lt 15 ]; then
    echo "MACOS_VERSION < 15"
    export OMP_PATH="/opt/homebrew/opt/libomp"
    export OpenMP_C_FLAGS="-Xpreprocessor -fopenmp -I${OMP_PATH}/include"
    export OpenMP_C_LIB_NAMES="omp"
    export OpenMP_omp_LIBRARY="${OMP_PATH}/lib/libomp.dylib"
    export CMAKE_PREFIX_PATH="${OMP_PATH}:${CMAKE_PREFIX_PATH}"
    export LDFLAGS="-L${OMP_PATH}/lib ${LDFLAGS}"
    export CPPFLAGS="-I${OMP_PATH}/include ${CPPFLAGS}"
    export LIBRARY_PATH="${OMP_PATH}/lib:${LIBRARY_PATH}"
    # export MACOSX_DEPLOYMENT_TARGET=13.0
    # Use local roaringbitmap source to avoid download in restricted networks
    export FETCHCONTENT_FULLY_DISCONNECTED=ON
    export FETCHCONTENT_SOURCE_DIR_roaringbitmap="${ROOT_DIR}/roaringbitmap-src"
fi

# Configure custom source file directory
[ -n "$SOURCE_DIR" ] && mv $SOURCE_DIR/* $ROOT_DIR

bash $CUR_DIR/$PROJECT_NAME-$VERSION.sh $PROJECT_DIR $PROJECT_NAME $VERSION $RELEASE