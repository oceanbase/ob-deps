#!/bin/bash
#
# Build vsag for Android arm64-v8a
# Depends on: roaringbitmap, boost (headers)
# Builds its own OpenBLAS, cpuinfo, fmt, spdlog, antlr4, nlohmann_json, etc.
#
source "$(dirname "$0")/common.sh"

NAME="vsag"
VERSION="0.18.0"

echo "=== Building $NAME $VERSION ==="

SRC=$(prepare_source vsag)
cd "$SRC"

# -----------------------------------------------------------------------
# Patch 1: aligned_alloc unavailable on Android API 24
# Use posix_memalign instead (available since API 16)
# -----------------------------------------------------------------------
UTILS_H="extern/diskann/DiskANN/include/utils.h"
if [[ -f "$UTILS_H" ]]; then
    # Target only the alloc_aligned function's #ifndef _WINDOWS block
    perl -0777 -pi -e 's/#ifndef _WINDOWS\n    \*ptr = ::aligned_alloc\(align, size\);/#if defined(__ANDROID__)\n    if (::posix_memalign(ptr, align, size) != 0)\n        *ptr = nullptr;\n#elif !defined(_WINDOWS)\n    *ptr = ::aligned_alloc(align, size);/' "$UTILS_H"
fi

# -----------------------------------------------------------------------
# Patch 2: Remove -lpthread and -ldl from VSAG_DEP_LIBS
# Android Bionic has these built into libc
# -----------------------------------------------------------------------
SRC_CMAKE="src/CMakeLists.txt"
if [[ -f "$SRC_CMAKE" ]]; then
    sed -i '' 's/ pthread / /g; s/ dl / /g' "$SRC_CMAKE"
fi

# -----------------------------------------------------------------------
# Patch 3: Guard -static-libstdc++ and -stdlib=libstdc++ for non-Android
# NDK uses libc++ via ANDROID_STL; these flags are incompatible
# -----------------------------------------------------------------------
MAIN_CMAKE="CMakeLists.txt"
if [[ -f "$MAIN_CMAKE" ]]; then
    # Wrap -static-libstdc++ calls with if(NOT ANDROID)
    sed -i '' '/vsag_add_exe_linker_flag (-static-libstdc++)/i\
if(NOT ANDROID)' "$MAIN_CMAKE"
    sed -i '' '/vsag_add_shared_linker_flag (-static-libstdc++)/a\
endif()' "$MAIN_CMAKE"
    # Guard -stdlib=libstdc++ for non-Android
    sed -i '' 's/set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -stdlib=libstdc++")/if(NOT ANDROID)\
        set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -stdlib=libstdc++")\
    endif()/' "$MAIN_CMAKE"
fi

# -----------------------------------------------------------------------
# Patch 4: spdlog ExternalProject -- pass NDK toolchain
# spdlog.cmake uses CONFIGURE_COMMAND (bare cmake), not CMAKE_ARGS
# -----------------------------------------------------------------------
SPDLOG_CMAKE="extern/spdlog/spdlog.cmake"
if [[ -f "$SPDLOG_CMAKE" ]]; then
    sed -i '' "s|cmake -DCMAKE_INSTALL_PREFIX=\${install_dir} -S. -Bbuild|cmake -DCMAKE_TOOLCHAIN_FILE=${NDK_TOOLCHAIN_FILE} -DANDROID_ABI=${ANDROID_ABI} -DANDROID_PLATFORM=${ANDROID_PLATFORM} -DANDROID_STL=c++_static -DCMAKE_INSTALL_PREFIX=\${install_dir} -S. -Bbuild|" "$SPDLOG_CMAKE"
fi

# -----------------------------------------------------------------------
# Patch 5: antlr4 ExternalProject -- pass NDK toolchain
# antlr4.cmake uses CONFIGURE_COMMAND with ${common_cmake_args}
# -----------------------------------------------------------------------
ANTLR4_CMAKE="extern/antlr4/antlr4.cmake"
if [[ -f "$ANTLR4_CMAKE" ]]; then
    sed -i '' "s|cmake \${common_cmake_args}|cmake \${common_cmake_args} -DCMAKE_TOOLCHAIN_FILE=${NDK_TOOLCHAIN_FILE} -DANDROID_ABI=${ANDROID_ABI} -DANDROID_PLATFORM=${ANDROID_PLATFORM} -DANDROID_STL=c++_static|" "$ANTLR4_CMAKE"
fi

# -----------------------------------------------------------------------
# Patch 6: OpenBLAS -- cross-compile for Android ARM64
# Replace the default x86 DYNAMIC_ARCH build with ARM-specific flags
# -----------------------------------------------------------------------
OPENBLAS_CMAKE="extern/openblas/openblas.cmake"
if [[ -f "$OPENBLAS_CMAKE" ]]; then
    # Replace the entire BUILD_COMMAND and INSTALL_COMMAND with Android-specific ones
    # The original uses ${common_configure_envs} which doesn't include --sysroot
    cat > "$OPENBLAS_CMAKE" << OPENBLAS_EOF
set(name openblas)
set(source_dir \${CMAKE_CURRENT_BINARY_DIR}/\${name}/source)
set(install_dir \${CMAKE_CURRENT_BINARY_DIR}/\${name}/install)

ExternalProject_Add(
    \${name}
    URL https://github.com/OpenMathLib/OpenBLAS/releases/download/v0.3.23/OpenBLAS-0.3.23.tar.gz
        http://vsagcache.oss-rg-china-mainland.aliyuncs.com/openblas/OpenBLAS-0.3.23.tar.gz
    URL_HASH MD5=115634b39007de71eb7e75cf7591dfb2
    DOWNLOAD_NAME OpenBLAS-v0.3.23.tar.gz
    PREFIX \${CMAKE_CURRENT_BINARY_DIR}/\${name}
    TMP_DIR \${BUILD_INFO_DIR}
    STAMP_DIR \${BUILD_INFO_DIR}
    DOWNLOAD_DIR \${DOWNLOAD_DIR}
    SOURCE_DIR \${source_dir}
    CONFIGURE_COMMAND ""
    BUILD_COMMAND
        env
        CC=${TOOLCHAIN}/bin/aarch64-linux-android24-clang
        HOSTCC=cc
        make NOFORTRAN=1 TARGET=ARMV8 CROSS=1
            USE_THREAD=0 USE_LOCKING=1 NO_LAPACK=0
            -j\${NUM_BUILDING_JOBS}
    INSTALL_COMMAND
        make NOFORTRAN=1 TARGET=ARMV8 PREFIX=\${install_dir} install
    BUILD_IN_SOURCE 1
    LOG_CONFIGURE TRUE
    LOG_BUILD TRUE
    LOG_INSTALL TRUE
    DOWNLOAD_NO_PROGRESS 1
    INACTIVITY_TIMEOUT 5
    TIMEOUT 30
)

include_directories(\${install_dir}/include)
link_directories(\${install_dir}/lib)
link_directories(\${install_dir}/lib64)
OPENBLAS_EOF
fi

# -----------------------------------------------------------------------
# Patch 7: mkl.cmake -- fix BLAS_LIBRARIES for Android
# Default sets "omp libopenblas.a gfortran" but Android has no gfortran
# and OpenMP is linked via -static-openmp
# -----------------------------------------------------------------------
MKL_CMAKE="extern/mkl/mkl.cmake"
if [[ -f "$MKL_CMAKE" ]]; then
    # Remove gfortran from BLAS_LIBRARIES (Android has no Fortran runtime)
    sed -i '' 's/set(BLAS_LIBRARIES libopenblas.a gfortran)/set(BLAS_LIBRARIES libopenblas.a)/' "$MKL_CMAKE"
fi

# -----------------------------------------------------------------------
# Patch 8: Use pre-built boost from PREFIX instead of vsag's internal build
# vsag downloads boost 1.67.0 and builds it, but the host b2 can't cross-compile.
# Replace the ExternalProject with a stub that uses our pre-built boost headers.
# -----------------------------------------------------------------------
BOOST_CMAKE="extern/boost/boost.cmake"
if [[ -f "$BOOST_CMAKE" ]]; then
    cat > "$BOOST_CMAKE" << BOOST_EOF
# Replaced: use pre-built boost from system prefix instead of ExternalProject
add_custom_target(boost)
include_directories(SYSTEM $PREFIX/include)
link_directories($PREFIX/lib)
BOOST_EOF
fi

# -----------------------------------------------------------------------
# Patch 9: DefaultLogger -- use fprintf(stderr) instead of spdlog on Android
# spdlog headers may not be in the include path during compilation
# -----------------------------------------------------------------------
LOGGER_CPP="src/impl/logger/default_logger.cpp"
if [[ -f "$LOGGER_CPP" ]]; then
    cat > "$LOGGER_CPP" << 'LOGGER_EOF'
// Copyright 2024-present the vsag project
// Modified for Android: uses fprintf(stderr) instead of spdlog

#include "default_logger.h"

#ifdef __ANDROID__
#include <cstdio>

namespace vsag {
void DefaultLogger::SetLevel(Logger::Level log_level) { (void)log_level; }
void DefaultLogger::Trace(const std::string& msg) { fprintf(stderr, "[TRACE] %s\n", msg.c_str()); }
void DefaultLogger::Debug(const std::string& msg) { fprintf(stderr, "[DEBUG] %s\n", msg.c_str()); }
void DefaultLogger::Info(const std::string& msg) { fprintf(stderr, "[INFO] %s\n", msg.c_str()); }
void DefaultLogger::Warn(const std::string& msg) { fprintf(stderr, "[WARN] %s\n", msg.c_str()); }
void DefaultLogger::Error(const std::string& msg) { fprintf(stderr, "[ERROR] %s\n", msg.c_str()); }
void DefaultLogger::Critical(const std::string& msg) { fprintf(stderr, "[CRITICAL] %s\n", msg.c_str()); }
}  // namespace vsag

#else
#include <spdlog/spdlog.h>

namespace vsag {
void DefaultLogger::SetLevel(Logger::Level log_level) { spdlog::set_level((spdlog::level::level_enum)log_level); }
void DefaultLogger::Trace(const std::string& msg) { spdlog::trace(msg); }
void DefaultLogger::Debug(const std::string& msg) { spdlog::debug(msg); }
void DefaultLogger::Info(const std::string& msg) { spdlog::info(msg); }
void DefaultLogger::Warn(const std::string& msg) { spdlog::warn(msg); }
void DefaultLogger::Error(const std::string& msg) { spdlog::error(msg); }
void DefaultLogger::Critical(const std::string& msg) { spdlog::critical(msg); }
}  // namespace vsag
#endif
LOGGER_EOF
fi

# -----------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------
STAGING="$BUILD_DIR/${NAME}_staging"
rm -rf "$STAGING" && mkdir -p "$STAGING"

mkdir -p build_android && cd build_android

cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=$NDK_TOOLCHAIN_FILE \
    -DANDROID_ABI=$ANDROID_ABI \
    -DANDROID_PLATFORM=$ANDROID_PLATFORM \
    -DANDROID_STL=c++_static \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$STAGING" \
    -DENABLE_INTEL_MKL=OFF \
    -DENABLE_CXX11_ABI=OFF \
    -DENABLE_LIBCXX=OFF \
    -DENABLE_TOOLS=OFF \
    -DENABLE_EXAMPLES=OFF \
    -DENABLE_TESTS=OFF \
    -DENABLE_PYBINDS=OFF \
    -DENABLE_WERROR=OFF \
    -DDISABLE_SSE_FORCE=ON \
    -DDISABLE_AVX_FORCE=ON \
    -DDISABLE_AVX2_FORCE=ON \
    -DDISABLE_AVX512_FORCE=ON \
    -DCMAKE_PREFIX_PATH="$PREFIX" \
    -DCMAKE_FIND_ROOT_PATH="$PREFIX;$TOOLCHAIN/sysroot" \
    -DCMAKE_CXX_FLAGS="-D_LIBCPP_ENABLE_CXX17_REMOVED_UNARY_BINARY_FUNCTION -D__ANDROID__ -I$PREFIX/include -I$PREFIX/include/roaring"

make

# Collect built libraries
mkdir -p "$STAGING/lib" "$STAGING/include"
# Main vsag library
find . -name 'libvsag_static.a' -exec cp {} "$STAGING/lib/" \;
find . -name 'libvsag.a' -exec cp {} "$STAGING/lib/" \;
# Sub-libraries
for lib in libdiskann.a libsimd.a libcpuinfo.a libfmt.a libopenblas.a \
           libspdlog.a libantlr4-runtime.a libantlr4-autogen.a; do
    found=$(find . -name "$lib" \( -type f -o -type l \) | head -1)
    if [[ -n "$found" ]]; then
        cp "$found" "$STAGING/lib/"
    fi
done
# OpenBLAS may install as versioned name (e.g. libopenblas_armv8-r0.3.23.a)
if [[ ! -f "$STAGING/lib/libopenblas.a" ]]; then
    found=$(find . -name 'libopenblas*.a' -type f | head -1)
    if [[ -n "$found" ]]; then
        cp "$found" "$STAGING/lib/libopenblas.a"
    fi
fi

# Headers
cp -r ../include/vsag "$STAGING/include/" 2>/dev/null || true

install_to_prefix "$STAGING"
package_dep "$NAME" "$VERSION" "$STAGING"
echo "=== $NAME $VERSION done ==="
