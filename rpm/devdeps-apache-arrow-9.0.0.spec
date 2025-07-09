Name: devdeps-apache-arrow
Version: 9.0.0
Release: %(echo $RELEASE)%{?dist}
Summary: This is the repository for in-memory analytics
License: https://github.com/apache/arrow/blob/main/LICENSE.txt
AutoReqProv:no

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat
# support debuginfo package, to reduce runtime package size
%define debug_package %{nil}
%define _prefix /usr/local/oceanbase/deps/devel
%define _product_prefix apache-arrow
%define _src apache-arrow-%{version}

%description
This is the repository for in-memory analytics

%install
# create dirs
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/lib64
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
export CFLAGS="-fPIC -fPIE -D_GLIBCXX_USE_CXX11_ABI=0 -fstack-protector-strong"
export CXXFLAGS="-fPIC -fPIE -D_GLIBCXX_USE_CXX11_ABI=0 -fstack-protector-strong"
export LDFLAGS="-z noexecstack -z now -pie"
ROOT_DIR=$OLDPWD/..

cd $ROOT_DIR
tmp_dir=$(pwd)
build_dir=${tmp_dir}/%{_src}/cpp/build
rm -rf %{_src}
tar -xf %{_src}.tar.gz
cp icu-makefiles/CMakeLists-%{version}.txt %{_src}/CMakeLists.txt
cd %{_src}/cpp
source_dir=$(pwd)
tmp_install_dir=${source_dir}/tmp_install_dir
build_dir=${source_dir}/build
rm -rf ${tmp_install_dir}
rm -rf ${build_dir}
mkdir -p ${tmp_install_dir}
mkdir -p ${build_dir}
 
# compile and install
cd ${build_dir}
cmake .. -DCMAKE_C_COMPILER=$TOOLS_DIR/bin/gcc -DCMAKE_CXX_COMPILER=$TOOLS_DIR/bin/g++ \
         -DCMAKE_INSTALL_PREFIX=${tmp_install_dir} -DCMAKE_BUILD_TYPE=Release -DARROW_PARQUET=ON \
         -DPARQUET_BUILD_EXAMPLES=ON -DARROW_FILESYSTEM=ON -DARROW_WITH_BROTLI=ON -DARROW_WITH_BZ2=ON \
         -DARROW_WITH_LZ4=ON -DARROW_WITH_SNAPPY=ON -DARROW_WITH_ZLIB=ON -DARROW_WITH_ZSTD=ON -Djemalloc_SOURCE=SYSTEM
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

# package infomation
%files 
# set file attribute here
%defattr(-,root,root)
# need not list every file here, keep it as this
%{_prefix}
%exclude %dir %{_prefix}
%exclude %dir %{_prefix}/include
%exclude %dir %{_prefix}/lib64
 
%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig
 
%changelog
* Tue May 21 2024 jim.wjh
- version 1
