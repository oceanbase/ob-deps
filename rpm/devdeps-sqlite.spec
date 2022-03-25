Name: devdeps-sqlite
Version: 3.38.1
Release: %(echo $RELEASE)%{?dist}

Summary: SQLite is a C-language library that implements a small, fast, self-contained, high-reliability, full-featured, SQL database engine.

License: Public Domain
Url: https://github.com/sqlite/sqlite
AutoReqProv:no

%undefine _missing_build_ids_terminate_build
# disable check-buildroot
%define __arch_install_post %{nil}
%define _buliddir %{_topdir}/BUILD
%define _tmppath %{_buliddir}/_tmp
%define _prefix /usr/local/oceanbase/deps/devel
%define _sqlite_src sqlite-version-%{version}
%define debug_package %{nil}

%description
SQLite is a C-language library that implements a small, fast, self-contained, high-reliability, full-featured, SQL database engine.

%install
mkdir -p %{buildroot}/%{_prefix}/lib/sqlite
mkdir -p %{buildroot}/%{_prefix}/include/sqlite
cd $OLDPWD/../
rm -rf %{_sqlite_src}
tar xf %{_sqlite_src}.tar.gz
cd %{_sqlite_src}
./configure --prefix=%{_tmppath} --enable-shared=no
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make -j${CPU_CORES}
make install
cp %{_tmppath}/include/*.h %{buildroot}/%{_prefix}/include/sqlite
cp %{_tmppath}/lib/*.a %{buildroot}/%{_prefix}/lib/sqlite

%files

%defattr(-,root,root)

%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Fri Mar 25 2022 oceanbase
- sqlite 3.38.1