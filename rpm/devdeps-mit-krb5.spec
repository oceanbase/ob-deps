Name: devdeps-mit-krb5
Version: 1.21.3
Release: %(echo $RELEASE)%{?dist}
Summary: This is the repository for accessing hive metastore by krb5
License: https://github.com/krb5/krb5/blob/krb5-1.21/NOTICE
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

# reset config about krb5 source code
sed -E -i 's/^AC_DEFINE\(KRB5_DNS_LOOKUP, 1,\[Define for DNS support of locating realms and KDCs\]\)/dnl &/' aclocal.m4
# re-generate make file by -f (force)
autoreconf -vi -f

./configure --prefix=%_compiled_prefix --disable-shared --enable-static --without-system-verto --without-libedit --without-ldap --disable-rpath --disable-pkinit --with-crypto-impl=builtin --without-tls-impl --disable-nls --without-keyutils --enable-dns-for-realm=no  CFLAGS="-g -O2 -fPIC" CXXFLAGS="-g -O2 -fPIC"

make
make install

## list files
ls -R %_compiled_prefix

## install kerberos5 static library
cp %_compiled_libs/libgssapi_krb5.a $RPM_BUILD_ROOT/%{_prefix}/lib/%{_product_prefix}
cp %_compiled_libs/libkrb5.a $RPM_BUILD_ROOT/%{_prefix}/lib/%{_product_prefix}
cp %_compiled_libs/libk5crypto.a $RPM_BUILD_ROOT/%{_prefix}/lib/%{_product_prefix}
cp %_compiled_libs/libkrb5support.a $RPM_BUILD_ROOT/%{_prefix}/lib/%{_product_prefix}
cp %_compiled_libs/libcom_err.a $RPM_BUILD_ROOT/%{_prefix}/lib/%{_product_prefix}

cp -r %_header_files/* $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}/

%files 

%defattr(-,root,root)

%{_prefix}
%exclude %dir %{_prefix}
%exclude %dir %{_prefix}/include
%exclude %dir %{_prefix}/lib

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Wed Jun 12 2025 xutengting.xtt
- version 1.21.3