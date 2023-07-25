Name: devdeps-mariadb-connector-c
Version: 3.1.12
Release: %(echo $RELEASE)%{?dist}
Summary: This is LGPL MariaDB client library that can be used to connect to MySQL or MariaDB.
Url: https://github.com/mariadb-corporation/mariadb-connector-c
Group: oceanbase-devel/dependencies
License: LGPL-2.1

# disable check-buildroot
%define __arch_install_post %{nil}

%define _prefix /usr/local/oceanbase/deps/devel
%define _buliddir %{_topdir}/BUILD
%define _tmppath %{_buliddir}/_tmp
%define _src mariadb-connector-c-%{version}
%define debug_package %{nil}
%define __strip /bin/true

%description
This is LGPL MariaDB client library that can be used to connect to MySQL or MariaDB.

%build

rm -rf %{_tmppath}
mkdir -p %{_tmppath}
cd $OLDPWD/../
rm -rf %{_src}
tar -xf %{_src}.tar.gz
cd %{_src}
mkdir -p build-rpm;
cd build-rpm
cmake .. -DCMAKE_INSTALL_PREFIX=%{_tmppath} -DCMAKE_BUILD_TYPE=RelWithDebInfo -DWITH_SSL=system -DENABLED_LOCAL_INFILE=1 -DDEFAULT_CHARSET=utf8
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
- add spec of mariadb-connector-c
