#!/bin/bash

CUR_DIR=$(dirname $(readlink -f "$0"))
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-vsag"}
VERSION=${3:-"1.1.0"}
RELEASE=${4:-"1"}

# check source code
if [[ -z `find $ROOT_DIR -maxdepth 1 -regex ".*/vsag"` ]]; then
  echo "Download $PROJECT_NAME source code"
  cd $ROOT_DIR
  git clone https://github.com/stuBirdFly/vsag.git -b compat_mac --depth=10
fi

# init build package env
echo "[BUILD] args: CURDIR=${CUR_DIR} PROJECT_NAME=${PROJECT_NAME} VERSION=${VERSION} RELEASE=${RELEASE}"
CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || grep -c ^processor /proc/cpuinfo)
TOP_DIR=$CUR_DIR/.pkg_build/usr/local/oceanbase/deps/devel
rm -rf $TOP_DIR && mkdir -p $TOP_DIR

# brew install libomp lapack gcc #llvm@17

# compile and install
TMP_DIR=$CUR_DIR/$PROJECT_NAME
rm -rf $TMP_DIR && mkdir -p $TMP_DIR
TMP_INSTALL=$TMP_DIR/tmp_install
rm -rf $TMP_INSTALL && mkdir -p $TMP_INSTALL
cd $TMP_DIR
cp -r $ROOT_DIR/vsag ./
cd vsag && mkdir build && cd build
cmake .. \
  -DENABLE_LIBCXX=ON \
  -DENABLE_TESTS=OFF \
  -DCMAKE_C_COMPILER=${DEV_TOOLS}/bin/clang \
  -DCMAKE_CXX_COMPILER=${DEV_TOOLS}/bin/clang++
  # -DCMAKE_CXX_FLAGS="-fPIC -isysroot ${SDKROOT}" \
  # -DCMAKE_C_FLAGS="-fPIC -isysroot ${SDKROOT}" \
  # -DCMAKE_EXE_LINKER_FLAGS="-isysroot ${SDKROOT}"

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
        sed -i '' 's|cxxflags=-fPIC ${extra_cpp_flags}|cxxflags=-fPIC \${extra_cpp_flags} -std=c++17|' $TMP_DIR/vsag/extern/boost/boost.cmake

        # Add extra C++ flags configuration to boost.cmake
        sed -i '' "/^get_filename_component(compiler_path \${CMAKE_CXX_COMPILER} DIRECTORY)/r ${ROOT_DIR}/patch/append_boost_flags.txt" $TMP_DIR/vsag/extern/boost/boost.cmake

        cp ${ROOT_DIR}/patch/boost_unary_function_compat.h $TMP_DIR/vsag/extern/boost/boost_unary_function_compat.h
    fi

    if [ $retry_count -ge $max_retries ]; then
        echo "[Build] Build failed after $max_retries attempts."
        break
    fi

    echo "[Build] Build failed (attempt $retry_count/$max_retries). Retrying..."
done

mkdir -p ${TOP_DIR}/lib/vsag_lib
mkdir -p ${TOP_DIR}/include/vsag
cp ../include/vsag/* ${TOP_DIR}/include/vsag
cp ./src/libvsag.dylib ${TOP_DIR}/lib/vsag_lib
cp ./src/libvsag_static.a ${TOP_DIR}/lib/vsag_lib
cp ./src/simd/libsimd.a ${TOP_DIR}/lib/vsag_lib
cp ./_deps/cpuinfo-build/libcpuinfo.a ${TOP_DIR}/lib/vsag_lib
cp ./libdiskann.a ${TOP_DIR}/lib/vsag_lib
cp ./openblas/install/lib/libopenblas.a ${TOP_DIR}/lib/vsag_lib
cp ./antlr4/install/lib/libantlr4-runtime.a ${TOP_DIR}/lib/vsag_lib/
cp ./libantlr4-autogen.a ${TOP_DIR}/lib/vsag_lib/
# brew list gcc | grep libgfortran 
# brew list gcc | grep libgomp 
cp /opt/homebrew/Cellar/gcc/15.2.0/lib/gcc/current/libgfortran.5.dylib ${TOP_DIR}/lib/vsag_lib/
cp /opt/homebrew/Cellar/gcc/15.2.0/lib/gcc/current/libgomp.1.dylib ${TOP_DIR}/lib/vsag_lib/
cp /opt/homebrew/Cellar/gcc/15.2.0/lib/gcc/current/libgomp.a ${TOP_DIR}/lib/vsag_lib/libgomp_static.a

# build package
echo "[BUILD] build tarball......"
cd $CUR_DIR/.pkg_build/
tar -zcvf ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ./usr
mv ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ${CUR_DIR}
