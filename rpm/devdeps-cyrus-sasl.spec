Name: devdeps-cyrus-sasl
Version: 2.1.28
Release: %(echo $RELEASE)%{?dist}
Summary: This is the repository for accessing hive metastore with cyrus sasl
License: https://github.com/cyrusimap/cyrus-sasl/blob/master/COPYING
AutoReqProv:no

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat
# disable check-buildroot
%define __arch_install_post %{nil}
# support debuginfo package, to reduce runtime package size
## %define debug_package %{nil}

%define _prefix /usr/local/oceanbase/deps/devel
%define _src_path krb5-1.21.3
%define _src krb5-1.21.3
%define _product_prefix krb5
%define _sasl_src_path cyrus-sasl-2.1.28
%define _sasl_src cyrus-sasl-2.1.28
%define _sasl_product_prefix cyrus-sasl

# prepare env variables for compiling thrift 
%define _compiled_prefix /usr/local
%define _compiled_libs %_compiled_prefix/lib
%define _header_files %_compiled_prefix/include/

%define _sasl_compiled_prefix /usr/local
%define _sasl_compiled_libs %_sasl_compiled_prefix/lib
%define _sasl_header_files %_sasl_compiled_prefix/include/sasl

%description
This is the repository for accessing hive metastore by krb5

%install
# create dirs
## create krb5 related
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/lib/%{_product_prefix}
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}
## create cyrus sasl related
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/lib/%{_sasl_product_prefix}
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/include/%{_sasl_product_prefix}

CPU_CORES=`grep -c ^processor /proc/cpuinfo`
ROOT_DIR=$OLDPWD/..

cd $ROOT_DIR

# compile and install `krb5`, note: use gcc and g++ as same as the compiler of observer

rm -rf %{_src_path}
tar xf %{_src}.tar.gz
cd %{_src_path}/src

# reset config about krb5 source code and compile dynamic libraries
sed -E -i 's/^AC_DEFINE\(KRB5_DNS_LOOKUP, 1,\[Define for DNS support of locating realms and KDCs\]\)/dnl &/' aclocal.m4
# re-generate make file by -f (force)
autoreconf -vi -f

./configure --prefix=%_compiled_prefix --without-system-verto --without-libedit --without-ldap --disable-rpath --disable-pkinit --with-crypto-impl=builtin --without-tls-impl --disable-nls --without-keyutils --enable-dns-for-realm=no  CFLAGS="-g -O2 -fPIC" CXXFLAGS="-g -O2 -fPIC"

make
make install

## list files about krb5
ls -R %_compiled_prefix

## check krb5 
nm -AC %_compiled_prefix/lib/*.so | grep gss_unwrap

cd $ROOT_DIR
# compile and install `cyrus sasl`, note: use gcc and g++ as same as the compiler of observer
rm -rf %{_sasl_src_path}
tar xf %{_sasl_src}.tar.gz
cd %{_sasl_src}

./configure --prefix=%_sasl_compiled_prefix --enable-gssapi=%_compiled_prefix --enable-static --enable-otp=no --enable-scram=no --enable-digest=no --enable-staticdlopen=yes --with-gss_impl=mit --with-dblib=none CFLAGS="-g -O2 -fPIC" CXXFLAGS="-g -O2 -fPIC"

make
make install

## install cyrus sasl
ls -alh %_sasl_compiled_libs/libsasl2.a

cp %_sasl_compiled_libs/libsasl2.a $RPM_BUILD_ROOT/%{_prefix}/lib/%{_sasl_product_prefix}

cp -r %_sasl_header_files/* $RPM_BUILD_ROOT/%{_prefix}/include/%{_sasl_product_prefix}/

echo "show config cache ..."
cat config.cache

%files 

%defattr(-,root,root)

%{_prefix}
%exclude %dir %{_prefix}
%exclude %dir %{_prefix}/include
%exclude %dir %{_prefix}/lib

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Wed Jun 19 2025 xutengting.xtt
- version 2.1.28