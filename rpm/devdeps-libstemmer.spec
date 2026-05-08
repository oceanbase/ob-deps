Name: devdeps-libstemmer
Version: %(echo $VERSION)
Release: %(echo $RELEASE)%{?dist}
Summary: Snowball stemmer C library and example tool

Url: https://snowballstem.org/
Group: oceanbase-devel/dependencies
License: BSD

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat

# disable check-buildroot
%define __arch_install_post %{nil}

%define _prefix /usr/local/oceanbase/deps/devel
%define _src libstemmer-%{version}

%define debug_package %{nil}
%define __strip /bin/true

%define _buliddir %{_topdir}/BUILD
%define _tmppath %{_buliddir}/_tmp

%description
Headers and static library for developing against libstemmer.

%install
ROOT_DIR=$OLDPWD/..
export CFLAGS="-O2 -fPIC -pie -fstack-protector-strong"
export CXXFLAGS="-O2 -fPIC -pie -fstack-protector-strong"
export CPPFLAGS="${ABI_CXXFLAGS}"
export LDFLAGS="-pie -z noexecstack -z now"

cd $ROOT_DIR
rm -rf %{_src}
tar xf %{_src}.tar.gz
cd snowball-%{version}/
make dist_libstemmer_c
cd dist/
tar -xf libstemmer_c-%{version}.tar.gz
cd libstemmer_c-%{version}/
make

mkdir -p $RPM_BUILD_ROOT/%{_prefix}/lib
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/include
cp ./libstemmer.a $RPM_BUILD_ROOT/%{_prefix}/lib
cp -r ./include/* $RPM_BUILD_ROOT/%{_prefix}/include

%files

%defattr(-,root,root)
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Fri Apr 2 2021 oceanbase
- add spec of libstemmer
