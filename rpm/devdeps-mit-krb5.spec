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
# %define debug_package %{nil}

%define _prefix /usr/local/oceanbase/deps/devel
%define _src krb5-1.21.3
%define _product_prefix krb5

%description
This is the repository for accessing hive metastore by krb5

%install
# create create krb5 related dirs
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/lib/%{_product_prefix}
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}

CPU_CORES=`grep -c ^processor /proc/cpuinfo`
ROOT_DIR=$OLDPWD/..
# prepare env variables for compiling thrift 
_compiled_prefix=${ROOT_DIR}/tmp_krb5

cd $ROOT_DIR

# compile and install `krb5`, note: use gcc and g++ as same as the compiler of observer

rm -rf %{_src}
tar xf %{_src}.tar.gz
cd %{_src}/src

# reset config about krb5 source code
sed -E -i 's/^AC_DEFINE\(KRB5_DNS_LOOKUP, 1,\[Define for DNS support of locating realms and KDCs\]\)/dnl &/' aclocal.m4
# re-generate make file by -f (force)
autoreconf -vi -f

./configure --prefix=${_compiled_prefix} --disable-shared --enable-static --without-system-verto --without-libedit --without-ldap --disable-rpath --disable-pkinit --with-crypto-impl=builtin --without-tls-impl --disable-nls --without-keyutils --enable-dns-for-realm=no  CFLAGS="-g -O2 -fPIC" CXXFLAGS="-g -O2 -fPIC"

make
make install

## list files
ls -R ${_compiled_prefix}

## install kerberos5 static library
cp ${_compiled_prefix}/lib/libgssapi_krb5.a $RPM_BUILD_ROOT/%{_prefix}/lib/%{_product_prefix}
cp ${_compiled_prefix}/lib/libkrb5.a $RPM_BUILD_ROOT/%{_prefix}/lib/%{_product_prefix}
cp ${_compiled_prefix}/lib/libk5crypto.a $RPM_BUILD_ROOT/%{_prefix}/lib/%{_product_prefix}
cp ${_compiled_prefix}/lib/libkrb5support.a $RPM_BUILD_ROOT/%{_prefix}/lib/%{_product_prefix}
cp ${_compiled_prefix}/lib/libcom_err.a $RPM_BUILD_ROOT/%{_prefix}/lib/%{_product_prefix}

cp -r ${_compiled_prefix}/include/* $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}/

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