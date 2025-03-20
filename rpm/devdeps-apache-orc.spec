Name: devdeps-apache-orc
Version: 2.1.1
Release: %(echo $RELEASE)%{?dist}
Summary: This is the repository for in-memory analytics
License: https://github.com/apache/orc?tab=Apache-2.0-1-ov-file
AutoReqProv:no
%undefine _missing_build_ids_terminate_build
# support debuginfo package, to reduce runtime package size
%define debug_package %{nil}
%define _build_id_links compat
%define _prefix /usr/local/oceanbase/deps/devel
%define _product_prefix apache-orc
%define _src orc-%{version}
%define _cmake_src cmake-3.22.1

%description
This is the repository for in-memory analytics

%install
# create dirs
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/lib64
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
ROOT_DIR=$OLDPWD/..

# install cmake
cd $ROOT_DIR
rm -rf %{_cmake_src}
mkdir -p %{_cmake_src}
tar zxf %{_cmake_src}.tar.gz --strip-components=1 -C %{_cmake_src}
cd %{_cmake_src}
./bootstrap --prefix=$ROOT_DIR/%{_cmake_src} -- -DCMAKE_USE_OPENSSL=ON
make -j${CPU_CORES}
make install
export PATH=$ROOT_DIR/%{_cmake_src}/bin:$PATH;

cd $ROOT_DIR
tmp_dir=$(pwd)
rm -rf %{_src}
mkdir -p %{_src}
tar zxf %{_src}.tar.gz --strip-components=1 -C %{_src}
cp icu-makefiles/ThirdpartyToolchain.cmake %{_src}/cmake_modules
cd %{_src}
source_dir=$(pwd)
tmp_install_dir=${source_dir}/tmp_install_dir
build_dir=${source_dir}/build
rm -rf ${tmp_install_dir}
rm -rf ${build_dir}
mkdir -p ${tmp_install_dir}
mkdir -p ${build_dir}

# compile and install
export CXXFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0"

cd ${build_dir}
cmake .. -DCMAKE_INSTALL_PREFIX=${RPM_BUILD_ROOT}/%{_prefix} \
         -DBUILD_JAVA=OFF -DBUILD_CPP_TESTS=OFF -DBUILD_TOOLS=OFF \
         -DSTOP_BUILD_ON_WARNING=OFF -DCMAKE_C_COMPILER=$TOOLS_DIR/bin/gcc \
         -DCMAKE_CXX_COMPILER=$TOOLS_DIR/bin/g++ -DBUILD_POSITION_INDEPENDENT_LIB=ON -DBUILD_LIBHDFSPP=OFF
cp $tmp_dir/zlib-1.2.11.tar.gz $build_dir/zlib_ep-prefix/src/
cp $tmp_dir/1.1.7.tar.gz $build_dir/snappy_ep-prefix/src/
cp $tmp_dir/v3.5.1.tar.gz $build_dir/protobuf_ep-prefix/src/
cp $tmp_dir/v1.9.3.tar.gz $build_dir/lz4_ep-prefix/src/
cp $tmp_dir/v1.5.2.tar.gz $build_dir/zstd_ep-prefix/src/
sed -i '17s/FALSE/TRUE/' $build_dir/zlib_ep-prefix/src/zlib_ep-stamp/download-zlib_ep.cmake
sed -i '18s/FALSE/TRUE/' $build_dir/zlib_ep-prefix/src/zlib_ep-stamp/download-zlib_ep.cmake
sed -i '17s/FALSE/TRUE/' $build_dir/snappy_ep-prefix/src/snappy_ep-stamp/download-snappy_ep.cmake
sed -i '18s/FALSE/TRUE/' $build_dir/snappy_ep-prefix/src/snappy_ep-stamp/download-snappy_ep.cmake
sed -i '17s/FALSE/TRUE/' $build_dir/protobuf_ep-prefix/src/protobuf_ep-stamp/download-protobuf_ep.cmake
sed -i '18s/FALSE/TRUE/' $build_dir/protobuf_ep-prefix/src/protobuf_ep-stamp/download-protobuf_ep.cmake
sed -i '17s/FALSE/TRUE/' $build_dir/lz4_ep-prefix/src/lz4_ep-stamp/download-lz4_ep.cmake
sed -i '18s/FALSE/TRUE/' $build_dir/lz4_ep-prefix/src/lz4_ep-stamp/download-lz4_ep.cmake
sed -i '17s/FALSE/TRUE/' $build_dir/zstd_ep-prefix/src/zstd_ep-stamp/download-zstd_ep.cmake
sed -i '18s/FALSE/TRUE/' $build_dir/zstd_ep-prefix/src/zstd_ep-stamp/download-zstd_ep.cmake
make -j${CPU_CORES}
make install
 
# install files
mv $RPM_BUILD_ROOT/%{_prefix}/lib/* $RPM_BUILD_ROOT/%{_prefix}/lib64
rm -rf $RPM_BUILD_ROOT/%{_prefix}/lib
mv $RPM_BUILD_ROOT/%{_prefix}/include/orc $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}/

%files 

%defattr(-,root,root)
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Fri Jan 17 2025 huaixin.lmy
- version 1
