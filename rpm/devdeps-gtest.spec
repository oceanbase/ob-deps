Name: devdeps-gtest
Version: 1.8.0
Release: %(echo $RELEASE)%{?dist}
Summary: GoogleTest is Google's C++ testing and mocking framework
Group: oceanbase-devel/dependencies
License: BSD 3-Clause
Url: https://github.com/google/googletest

%define _prefix /usr/local/oceanbase/deps/devel
%define _buliddir %{_topdir}/BUILD
%define _tmppath %{_buliddir}/_tmp
%define _src googletest-release-%{version}
%define debug_package %{nil}
%define __strip /bin/true

%description
GoogleTest is Google's C++ testing and mocking framework

%build

rm -rf %{_tmppath}
mkdir -p %{_tmppath}
cd $OLDPWD/../
rm -rf %{_src}
tar -xf %{_src}.tar.gz
cd %{_src}
mkdir -p build-rpm
cd build-rpm
cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX=%{_tmppath} -G 'Unix Makefiles'
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
* Fri Apr 2 2021 oceanbase
- add spec of gtest
