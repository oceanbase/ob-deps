Name: devdeps-apache-avro-cpp
Version: %(echo $VERSION)
Release: %(echo $RELEASE)%{?dist}
Summary: This is the repository for apache avro-cpp
License: https://github.com/apache/avro/blob/main/LICENSE.txt
AutoReqProv:no

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat
# disable check-buildroot
%define __arch_install_post %{nil}
# support debuginfo package, to reduce runtime package size
%define debug_package %{nil}

%define _prefix /usr/local/oceanbase/deps/devel
%define _snappy_src snappy-1.2.2
%define _src apache-avro-cpp-%{version}
%define _product_prefix apache-avro-cpp

%description
This is the repository for apache-avro-cpp

%install
# env
export CFLAGS="-fPIC -pie -fstack-protector-strong"
export CXXFLAGS="-fPIC -pie -fstack-protector-strong"
export CPPFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0"
export LDFLAGS="-pie -z noexecstack -z now"
# create dirs
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/lib
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/lib64
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/include/
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
ROOT_DIR=$OLDPWD/..

# install snappy
cd $ROOT_DIR
cd %{_snappy_src}
cmake -S . -Bbuild -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX=./build/installed -DCMAKE_C_FLAGS="-g -O2 -fPIC" -DCMAKE_C_COMPILER=$TOOLS_DIR/bin/gcc -DCMAKE_CXX_FLAGS="-g -O2 -fPIC" -DCMAKE_CXX_COMPILER=$TOOLS_DIR/bin/g++ 
cd build
make -j${CPU_CORES}
make install

# install apache-avro-cpp
cd $ROOT_DIR
cd %{_src}/lang/c++

cmake -S. -Bbuild \
          -DCMAKE_INSTALL_PREFIX=./build/installed \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_C_FLAGS="-g -O2 -fPIC -I$ROOT_DIR/%{_snappy_src}/build/installed/include/" \
          -DCMAKE_C_COMPILER=$TOOLS_DIR/bin/gcc \
          -DCMAKE_CXX_FLAGS="-g -O2 -fPIC -I$ROOT_DIR/%{_snappy_src}/build/installed/include/" \
          -DCMAKE_CXX_COMPILER=$TOOLS_DIR/bin/g++ \
          -DCMAKE_PREFIX_PATH="$ROOT_DIR/%{_snappy_src}/build/installed/" \
          -DAVRO_BUILD_TESTS=OFF
cd build
make -j${CPU_CORES}
make install
patch installed/include/fmt/format.h < $ROOT_DIR/patch/avro-cpp-fmt.diff

# install files
cp $ROOT_DIR/%{_src}/lang/c++/build/installed/lib64/libfmt.a $RPM_BUILD_ROOT/%{_prefix}/lib64/
cp $ROOT_DIR/%{_src}/lang/c++/build/installed/lib/libavrocpp_s.a $RPM_BUILD_ROOT/%{_prefix}/lib/
cp -r $ROOT_DIR/%{_src}/lang/c++/build/installed/include/* $RPM_BUILD_ROOT/%{_prefix}/include/

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
* Tue Apr 15 2025 chendingchao.cdc
- version 1