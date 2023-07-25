Name: devdeps-zlib-static
Version: 1.2.7
Release: %(echo $RELEASE)%{?dist}
Url: https://curl.se/
Summary: zlib is a general purpose data compression library.

Group: oceanbase-devel/dependencies
License: MIT

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat

# disable check-buildroot
%define __arch_install_post %{nil}

%define _prefix /usr/local/oceanbase/deps/devel
%define _src zlib-%{version}

%define debug_package %{nil}
%define __strip /bin/true

%define _buliddir %{_topdir}/BUILD
%define _tmppath %{_buliddir}/_tmp

%description
zlib is a general purpose data compression library.

%build

rm -rf %{_tmppath}
mkdir -p %{_tmppath}
cd $OLDPWD/../

cd rpm

rm -rf %{_src}

tar -zxvf %{_src}.tar.gz
cd %{_src}

C_FALG='-fpic' ./configure --prefix=%{_tmppath} --static

CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make -j${CPU_CORES};
make install

%install

mkdir -p $RPM_BUILD_ROOT/%{_prefix}
cp -r %{_tmppath}/lib %{_tmppath}/include $RPM_BUILD_ROOT/%{_prefix}

%files 

%defattr(-,root,root)
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Tue Sep 29 2022 oceanbase
- add spec of zlib
