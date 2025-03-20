Name: devdeps-ncurses-static
Version: 6.4
Release: %(echo $RELEASE)%{?dist}
Url: http://invisible-island.net/ncurses/ncurses.html
Summary: Static libraries for the ncurses library

Group: oceanbase-devel/dependencies
License: MIT

%define _prefix /usr/local/oceanbase/deps/devel
%define _src ncurses-%{version}

%define debug_package %{nil}

%define _buliddir %{_topdir}/BUILD
%define _tmppath %{_buliddir}/_tmp

%description
The ncurses-static package includes static libraries of the ncurses library.

%build
rm -rf %{_tmppath}
mkdir -p %{_tmppath}
cd $OLDPWD/../
rm -rf %{_src}
tar -xf %{_src}.tar.gz
cd %{_src}
export CFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0 -fPIC -pie -fstack-protector-strong"
export CXXFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0 -fPIC -pie -fstack-protector-strong"
export LDFLAGS="-pie -z noexecstack -z now"
./configure --with-normal --enable-overwrite
make install DESTDIR=%{_tmppath}

%install
mkdir -p $RPM_BUILD_ROOT/%{_prefix}
cp -r %{_tmppath}/usr/lib %{_tmppath}/usr/include $RPM_BUILD_ROOT/%{_prefix}

%files 

%defattr(-,root,root)
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Thu Mar 20 2025 huaixin.lmy
- upgrade version to 6.4
* Fri Mar 26 2021 oceanbase
- add spec of ncurses