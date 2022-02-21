Name: devdeps-libunwind-static
Version: 1.6.2
Release: %(echo $RELEASE)%{?dist}
Summary: libunwind's goal is define a portable and efficient C programming interface (API) to determine the call-chain of a program

Url: https://github.com/libunwind/libunwind
Group: oceanbase-devel/dependencies
License: MIT


%undefine _missing_build_ids_terminate_build
%define _build_id_links compat

# disable check-buildroot
%define __arch_install_post %{nil}

%define _prefix /usr/local/oceanbase/deps/devel
%define _src libunwind-%{version}

%define debug_package %{nil}
%define __strip /bin/true

%define _buliddir %{_topdir}/BUILD
%define _tmppath %{_buliddir}/_tmp

%description
libunwind's goal is define a portable and efficient C programming interface (API) to determine the call-chain of a program

%build

rm -rf %{_tmppath}
mkdir -p %{_tmppath}
cd $OLDPWD/../
rm -rf %{_src}
tar -xf %{_src}.tar.gz
cd %{_src}
./configure --prefix=%{_tmppath} --enable-minidebuginfo=no --with-pic=yes --disable-weak-backtrace
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make -j${CPU_CORES};
make install;

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
- add spec of libunwind
