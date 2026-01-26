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
rm -rf $CUR_DIR/.pkg_build && mkdir -p $TOP_DIR

# compile and install
TMP_DIR=$CUR_DIR/$PROJECT_NAME
rm -rf $TMP_DIR && mkdir -p $TMP_DIR
TMP_INSTALL=$TMP_DIR/tmp_install
rm -rf $TMP_INSTALL && mkdir -p $TMP_INSTALL
cd $TMP_DIR
cp -r $ROOT_DIR/vsag ./
cd vsag && mkdir build && cd build
# 修改 build_make_args 行：在 USE_THREAD=0 前添加 BUILD_LAPACK=1
sed -i '' 's/set(build_make_args USE_THREAD=0/set(build_make_args BUILD_LAPACK=1 netlib USE_THREAD=0/' $TMP_DIR/vsag/extern/openblas/openblas.cmake
# 修改 install_make_args 行：在 DYNAMIC_ARCH=1 前添加 BUILD_LAPACK=1
sed -i '' 's/set(install_make_args DYNAMIC_ARCH=1/set(install_make_args BUILD_LAPACK=1 DYNAMIC_ARCH=1/' $TMP_DIR/vsag/extern/openblas/openblas.cmake

if [ "${MACOS_VERSION}" -lt 15 ]; then
  # Fix deprecated implicit 'this' capture for newer Clang
  sed -i '' 's/\[=\]() -> std::shared_ptr<T>/[=, this]() -> std::shared_ptr<T>/' \
    $TMP_DIR/vsag/src/utils/resource_object_pool.h
  
  sed -i '' 's/add_library (io OBJECT/add_library (io STATIC/' $TMP_DIR/vsag/src/io/CMakeLists.txt
  
  mkdir -p ./_deps/roaringbitmap-subbuild/roaringbitmap-populate-prefix/src/
  cp $ROOT_DIR/v3.0.1.tar.gz $TMP_DIR/vsag/build/_deps/roaringbitmap-subbuild/roaringbitmap-populate-prefix/src/v3.0.1.tar.gz

  cmake .. \
    -DENABLE_LIBCXX=ON \
    -DENABLE_TESTS=OFF \
    -DCMAKE_C_COMPILER=${DEV_TOOLS}/bin/clang \
    -DCMAKE_CXX_COMPILER=${DEV_TOOLS}/bin/clang++ \
    -DCMAKE_C_FLAGS="-I${OMP_PATH}/include" \
    -DCMAKE_CXX_FLAGS="-I${OMP_PATH}/include" \
    -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}" \
    -DCMAKE_EXE_LINKER_FLAGS="-L${OMP_PATH}/lib" \
    -DCMAKE_SHARED_LINKER_FLAGS="-L${OMP_PATH}/lib" \
    -DCMAKE_MODULE_LINKER_FLAGS="-L${OMP_PATH}/lib" \
    -DOpenMP_C_FLAGS="${OpenMP_C_FLAGS}" \
    -DOpenMP_C_LIB_NAMES="${OpenMP_C_LIB_NAMES}" \
    -DOpenMP_CXX_FLAGS="${OpenMP_C_FLAGS}" \
    -DOpenMP_CXX_LIB_NAMES="${OpenMP_C_LIB_NAMES}" \
    -DOpenMP_omp_LIBRARY="${OpenMP_omp_LIBRARY}"
else
  cmake .. \
    -DENABLE_LIBCXX=ON \
    -DENABLE_TESTS=OFF \
    -DCMAKE_C_COMPILER=${DEV_TOOLS}/bin/clang \
    -DCMAKE_CXX_COMPILER=${DEV_TOOLS}/bin/clang++
fi

max_retries=6
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
cp ./_deps/fmt-build/libfmt.a ${TOP_DIR}/lib/vsag_lib/
cp ./src/io/libio.a ${TOP_DIR}/lib/vsag_lib/
# brew list gcc | grep libgfortran 
# brew list gcc | grep libgomp
cp /opt/homebrew/Cellar/gcc/15.2.0/lib/gcc/current/libgfortran.a ${TOP_DIR}/lib/vsag_lib/libgfortran_static.a
cp /opt/homebrew/Cellar/gcc/15.2.0/lib/gcc/current/libgfortran.5.dylib ${TOP_DIR}/lib/vsag_lib/
cp /opt/homebrew/Cellar/gcc/15.2.0/lib/gcc/current/libgomp.1.dylib ${TOP_DIR}/lib/vsag_lib/
cp /opt/homebrew/Cellar/gcc/15.2.0/lib/gcc/current/libgomp.a ${TOP_DIR}/lib/vsag_lib/libgomp_static.a
cp /opt/homebrew/Cellar/gcc/15.2.0/lib/gcc/current/libquadmath.0.dylib ${TOP_DIR}/lib/vsag_lib/
cp /opt/homebrew/Cellar/gcc/15.2.0/lib/gcc/current/libquadmath.a ${TOP_DIR}/lib/vsag_lib/libquadmath_static.a
cp /opt/homebrew/opt/libomp/lib/libomp.a ${TOP_DIR}/lib/vsag_lib/libomp_static.a
cp /opt/homebrew/opt/libomp/lib/libomp.dylib ${TOP_DIR}/lib/vsag_lib/libomp.dylib
if [ "${MACOS_VERSION}" -lt 15 ]; then
  cp /opt/homebrew/Cellar/gcc//15.2.0/lib/gcc/current/gcc/aarch64-apple-darwin22/15/libgcc.a ${TOP_DIR}/lib/vsag_lib/
else
  cp /opt/homebrew/Cellar/gcc/15.2.0/lib/gcc/current/gcc/aarch64-apple-darwin24/15/libgcc.a ${TOP_DIR}/lib/vsag_lib/
fi

# build package
echo "[BUILD] build tarball......"
cd $CUR_DIR/.pkg_build/
tar -zcvf ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ./usr
mv ${PROJECT_NAME}-${VERSION}-${RELEASE}.tar.gz ${CUR_DIR}
