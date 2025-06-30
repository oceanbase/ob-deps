Name: devdeps-apache-thrift
Version: 0.16.0
Release: %(echo $RELEASE)%{?dist}
Summary: This is the repository for accessing hive metastore
License: https://github.com/apache/thrift/blob/0.16.0/LICENSE
AutoReqProv:no
%undefine _missing_build_ids_terminate_build
%define _build_id_links compat
# disable check-buildroot
%define __arch_install_post %{nil}
# support debuginfo package, to reduce runtime package size
%define debug_package %{nil}

%define _prefix /usr/local/oceanbase/deps/devel
%define _src_path thrift-0.16.0
%define _src thrift-0.16.0
%define _product_prefix thrift

# prepare env variables for compiling thrift 
%define _compiled_prefix /usr/local
%define _compiled_libs %_compiled_prefix/lib
%define _header_files %_compiled_prefix/include/thrift

%description
This is the repository for accessing hive metastore

%install
# create dirs
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/lib
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
ROOT_DIR=$OLDPWD/..

cd $ROOT_DIR

# unzip boost package, will get directory "boost_1_74_0"
tar xf boost_1_74_0.tar.bz2

# compile and install `thrift`, note: use gcc and g++ as same as the compiler of observer

rm -rf %{_src_path}
tar xf %{_src}.tar.gz
cd %{_src_path}

./configure  --with-c_glib=yes  --with-cpp=yes  --without-erlang --without-nodejs --without-python --without-py3 --without-perl --without-php --without-php_extension --without-ruby --without-haskell --without-go --without-swift --without-dotnetcore --without-qt5 --prefix=%{_compiled_prefix} --enable-tutorial=no --enable-tests=no CFLAGS="-g -O2 -fPIC" CXXFLAGS="-g -O2 -fPIC" --with-boost=$ROOT_DIR/boost_1_74_0

make
make install

## list files
ls -R %_compiled_prefix

## install thrift
cp %_compiled_libs/libthrift.a $RPM_BUILD_ROOT/%{_prefix}/lib/
cp -r %_header_files/* $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}/

## reset config.h file in thrift, it will be conflict with oceanbase source code.
sed -i 's/^#define PACKAGE_VERSION "0.16.0"/\/\/ #define PACKAGE_VERSION "0.16.0"/' $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}/config.h
sed -i 's/^#define PACKAGE_STRING "thrift 0.16.0"/\/\/ #define PACKAGE_STRING "thrift 0.16.0"/' $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}/config.h
sed -i 's/^#define PACKAGE_NAME "thrift"/\/\/ #define PACKAGE_NAME "thrift"/' $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}/config.h

%files 

%defattr(-,root,root)

%{_prefix}
%exclude %dir %{_prefix}
%exclude %dir %{_prefix}/include
%exclude %dir %{_prefix}/lib

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Wed Jun 11 2025 xutengting.xtt
- version 0.16.0
