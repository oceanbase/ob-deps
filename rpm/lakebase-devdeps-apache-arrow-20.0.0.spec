Name: lakebase-devdeps-apache-arrow
Version: 20.0.0
Release: %(echo $RELEASE)%{?dist}
Summary: Apache Arrow with Flight SQL support for Lakebase
License: https://github.com/apache/arrow/blob/main/LICENSE.txt
AutoReqProv: no

%undefine _missing_build_ids_terminate_build
# support debuginfo package, to reduce runtime package size
%define debug_package %{nil}
# disable .a strip
%define __brp_strip_static_archive %{nil}
%define _build_id_links compat
%define _prefix /usr/local/oceanbase/deps/devel
%define _product_prefix apache-arrow
%define _src apache-arrow-%{version}
%define is_centos7 %(if [ -n "$OS_RELEASE" ] && echo "$OS_RELEASE" | grep -q "CentOS Linux 7"; then echo 1; else echo 0; fi)
%if %{is_centos7}
# disable install post for el7
%global __os_install_post %{nil}
%endif

# Set RPM strip tool to LLVM to handle objects compiled by clang.
%global __strip ${TOOLS_DIR}/bin/llvm-strip

%description
Apache Arrow with Flight and Flight SQL enabled for Lakebase.

%install
# create dirs
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/lib64
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
DISABLE_ATOMIC=""
arch=`uname -p`
if [[ x"$arch" == x"aarch64" ]]; then
    DISABLE_ATOMIC="-mno-outline-atomics"
fi
export LD=${TOOLS_DIR}/bin/ld.lld
export CFLAGS="-fPIC -D_GNU_SOURCE -fstack-protector-strong $DISABLE_ATOMIC -gdwarf-4 -flto=thin --gcc-toolchain=${TOOLS_DIR} -fuse-ld=lld -isystem -I/usr/include"
export CXXFLAGS="-std=c++17 -fPIC -D_GNU_SOURCE -D_GLIBCXX_USE_CXX11_ABI=0 -fstack-protector-strong $DISABLE_ATOMIC -gdwarf-4 -flto=thin --gcc-toolchain=${TOOLS_DIR} -fuse-ld=lld -isystem -I/usr/include"
export LDFLAGS="-Wl,-z,noexecstack -Wl,-z,now -flto-jobs=8 -fuse-ld=${TOOLS_DIR}/bin/ld.lld --gcc-toolchain=${TOOLS_DIR} -fuse-ld=lld"
ROOT_DIR=$OLDPWD/..

# install apache-arrow
cd $ROOT_DIR
rm -rf %{_src}
tar xf %{_src}.tar.gz
cp icu-makefiles/CMakeLists.txt %{_src}

# apply patch files if they exist
cd %{_src}
git init
if [ -f "$ROOT_DIR/patch/apache-arrow-%{version}.patch" ]; then
    echo "Applying patch: apache-arrow-%{version}.patch"
    git apply --whitespace=fix ../patch/apache-arrow-%{version}.patch
fi

if [ -f "$ROOT_DIR/patch/apache-arrow-parquet-page-mgr-%{version}.patch" ]; then
    echo "Applying patch: apache-arrow-parquet-page-mgr-%{version}.patch"
    git apply --whitespace=fix ../patch/apache-arrow-parquet-page-mgr-%{version}.patch
fi

if [ -f "$ROOT_DIR/patch/apache-arrow-buffered-input-stream-gh-48311-%{version}.patch" ]; then
    echo "Applying patch: apache-arrow-buffered-input-stream-gh-48311-%{version}.patch"
    git apply --whitespace=fix ../patch/apache-arrow-buffered-input-stream-gh-48311-%{version}.patch
fi

if [ -f "$ROOT_DIR/patch/paimon-cpp-arrow-%{version}.diff" ]; then
    echo "Applying patch: paimon-cpp-arrow-%{version}.diff"
    git apply --whitespace=fix ../patch/paimon-cpp-arrow-%{version}.diff
fi

cd cpp
source_dir=$(pwd)
tmp_install_dir=${source_dir}/tmp_install_dir
build_dir=${source_dir}/build
rm -rf ${tmp_install_dir}
rm -rf ${build_dir}
mkdir -p ${tmp_install_dir}
mkdir -p ${build_dir}

# compile and install
cd ${build_dir}
cmake .. -DCMAKE_C_COMPILER=$TOOLS_DIR/bin/clang \
         -DCMAKE_CXX_COMPILER=$TOOLS_DIR/bin/clang++ \
         -DCMAKE_AR=$AR -DCMAKE_RANLIB=$RANLIB -DCMAKE_NM=$NM \
         -DCMAKE_LINKER=${TOOLS_DIR}/bin/ld.lld \
         -DCMAKE_C_FLAGS="${CFLAGS}" \
         -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
         -DCMAKE_CXX_LINK_FLAGS="${LDFLAGS}" \
         -DCMAKE_EXE_LINKER_FLAGS="${LDFLAGS}" \
         -DCMAKE_SHARED_LINKER_FLAGS="${LDFLAGS}" \
         -DCMAKE_MODULE_LINKER_FLAGS="${LDFLAGS}" \
         -DCMAKE_INSTALL_PREFIX=${tmp_install_dir} \
         -DCMAKE_PREFIX_PATH="${OB_DEPS_PREFIX}" \
         -DCMAKE_BUILD_TYPE=Release \
         -DBUILD_SHARED_LIBS=OFF -DARROW_BUILD_SHARED=OFF -DARROW_BUILD_STATIC=ON \
         -DARROW_PARQUET=ON -DPARQUET_BUILD_EXAMPLES=ON -DARROW_FILESYSTEM=ON \
         -DARROW_COMPUTE=ON -DARROW_DATASET=ON -DARROW_ACERO=ON -DARROW_IPC=ON \
         -DARROW_JSON=ON -DARROW_WITH_RE2=ON \
         -Dre2_SOURCE=SYSTEM \
         -DgRPC_SOURCE=SYSTEM \
         -DProtobuf_SOURCE=SYSTEM \
         -Dre2_DIR="${OB_DEPS_PREFIX}/lib64/cmake/re2" \
         -Dabsl_DIR="${OB_DEPS_PREFIX}/lib64/cmake/absl" \
         -DARROW_WITH_BROTLI=ON -DARROW_WITH_BZ2=ON -DARROW_WITH_LZ4=ON \
         -DARROW_WITH_SNAPPY=ON -DARROW_WITH_ZLIB=ON -DARROW_WITH_ZSTD=ON -DARROW_JEMALLOC=OFF \
         -DARROW_FLIGHT=ON -DARROW_FLIGHT_SQL=ON
# Temporarily disable error exit
set +e
MAX_RETRIES=3
retry_count=1
while [ $retry_count -le $MAX_RETRIES ]; do
    make -j${CPU_CORES}
    if [ $? -eq 0 ]; then
        echo "Build succeeded!"
        break
    else
        echo "Compile failed (attempt $retry_count/$MAX_RETRIES), retrying..."
        retry_count=$((retry_count+1))
    fi
done
# Re-enable error exit
set -e
# All retries failed, exiting with an error
if [ $retry_count -gt $MAX_RETRIES ]; then
    echo "FATAL: All retries failed!"
    exit 1
fi

make install

# install files
cp -r ${tmp_install_dir}/lib64/*.a $RPM_BUILD_ROOT/%{_prefix}/lib64
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}
cp -r ${tmp_install_dir}/include/* $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}/

# install snappy headers under apache-arrow directory
if [ -d "${build_dir}/snappy_ep/src/snappy_ep-install/include" ]; then
    mkdir -p $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}/snappy
    cp -r ${build_dir}/snappy_ep/src/snappy_ep-install/include/* $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}/snappy/
fi

# package information
%files
# set file attribute here, keep all files under the dependency prefix
%defattr(-,root,root)
%{_prefix}
%exclude %dir %{_prefix}
%exclude %dir %{_prefix}/include
%exclude %dir %{_prefix}/lib64

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Thu Aug 20 2026 OceanBase
- Add Lakebase-specific Arrow package with Flight SQL support
