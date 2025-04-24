Name: devdeps-apache-avro-c
Version: %(echo $VERSION)
Release: %(echo $RELEASE)%{?dist}
Summary: This is the repository for apache avro-c
License: https://github.com/apache/avro/blob/main/LICENSE.txt
AutoReqProv:no

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat
# disable check-buildroot
%define __arch_install_post %{nil}
# support debuginfo package, to reduce runtime package size
%define debug_package %{nil}

%define _prefix /usr/local/oceanbase/deps/devel
%define _jansson_src jansson-2.14.1
%define _snappy_src snappy-1.2.2
%define _src apache-avro-c-1.12.0
%define _product_prefix apache-avro-c

%description
This is the repository for apache-avro-C

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

# install jansson
cd $ROOT_DIR
rm -rf %{_jansson_src}
mkdir -p %{_jansson_src}
tar zxf %{_jansson_src}.tar.gz --strip-components 1 -C %{_jansson_src}
cd %{_jansson_src}
cmake -S . -Bbuild -DCMAKE_INSTALL_PREFIX=./build/installed -DCMAKE_BUILD_TYPE=Release -DJANSSON_BUILD_DOCS=OFF -DCMAKE_C_FLAGS="-g -O2 -fPIC" -DCMAKE_C_COMPILER=$TOOLS_DIR/bin/gcc
cd build
make -j${CPU_CORES}
make install

# install snappy
cd $ROOT_DIR
cd %{_snappy_src}
cmake -S . -Bbuild -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX=./build/installed -DCMAKE_C_FLAGS="-g -O2 -fPIC" -DCMAKE_C_COMPILER=$TOOLS_DIR/bin/gcc -DCMAKE_CXX_FLAGS="-g -O2 -fPIC" -DCMAKE_CXX_COMPILER=$TOOLS_DIR/bin/g++ 
cd build
make -j${CPU_CORES}
make install

# install apache-avro-c
cd $ROOT_DIR
rm -rf %{_src}
mkdir -p %{_src}
tar zxf %{_src}.tar.gz --strip-components=1 -C %{_src}
cd %{_src}
cmake -S. -Bbuild \
          -DCMAKE_INSTALL_PREFIX=./build/installed \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_C_FLAGS="-g -O2 -fPIC -I$ROOT_DIR/%{_snappy_src}/build/installed/include/" \
          -DCMAKE_C_COMPILER=$TOOLS_DIR/bin/gcc \
          -DCMAKE_PREFIX_PATH="$ROOT_DIR/%{_jansson_src}/build/installed/;$ROOT_DIR/%{_snappy_src}/build/installed/"
cd build
make -j${CPU_CORES}
make install

# install files
cp $ROOT_DIR/%{_jansson_src}/build/installed/lib/libjansson.a $RPM_BUILD_ROOT/%{_prefix}/lib/
cp $ROOT_DIR/%{_src}/build/installed/lib64/libavro.a $RPM_BUILD_ROOT/%{_prefix}/lib64/
cp -r $ROOT_DIR/%{_src}/build/installed/include/* $RPM_BUILD_ROOT/%{_prefix}/include/

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
