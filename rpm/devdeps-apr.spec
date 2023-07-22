Name: devdeps-apr
Version: 1.7.4
Release: %(echo $RELEASE)%{?dist}
Summary: The APR and APR-Util source
Group: oceanbase-devel/dependencies
License: BSD 3-Clause
Url: https://apr.apache.org/compiling_unix.html

%define _prefix /usr/local/oceanbase/deps/devel
%define _buliddir %{_topdir}/BUILD
%define _tmppath %{_buliddir}/_tmp
%define _src apr-%{version}
%define debug_package %{nil}
%define __strip /bin/true

%description
The APR and APR-Util source

%build

rm -rf %{_tmppath}
mkdir -p %{_tmppath}
cd $OLDPWD/../
rm -rf %{_src}
tar -xf %{_src}.tar.gz
cd %{_src}
export CFLAGS="-fPIC"
export CXXFLAGS="-fPIC"
./configure --prefix=%{_tmppath}
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
* Sat Jul 22 2023 oceanbase
- add spec of apr
