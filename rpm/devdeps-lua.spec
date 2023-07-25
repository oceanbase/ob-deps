##############################################################
# http://baike.corp.taobao.com/index.php/%E6%B7%98%E5%AE%9Drpm%E6%89%93%E5%8C%85%E8%A7%84%E8%8C%83 #
# http://www.rpm.org/max-rpm/ch-rpm-inside.html              #
##############################################################
Name: devdeps-lua
Version: 5.4.3
Release: %(echo $RELEASE)%{?dist}
# if you want use the parameter of rpm_create on build time,
# uncomment below
Summary: Lua static library for oceanbase
Group: Development/Tools
License: Commercial
Url: http://www.lua.org/ftp/lua-5.4.3.tar.gz

%define _prefix /usr/local/oceanbase/deps/devel
%define _src lua-%{version}
%define _to_inc %(zgrep -aPo --color=never '(?<=^TO_INC= ).*' ../%{_src}.tar.gz)
%define _to_lib %(zgrep -aPo --color=never '(?<=^TO_LIB= ).*' ../%{_src}.tar.gz)
%define __strip /bin/true
%define __os_install_post %{nil}
%define debug_package %{nil}
# %define _to_inc lua.h luaconf.h lualib.h lauxlib.h lua.hpp
# %define _to_lib liblua.a
# %define _grep_inc %(zgrep -aPo --color=never '(?<=^TO_INC= ).*' SOURCES/%{_src}.tar.gz)
# %define _grep_lib %(zgrep -aPo --color=never '(?<=^TO_LIB= ).*' SOURCES/%{_src}.tar.gz)


# uncomment below, if your building depend on other packages

#BuildRequires: package_name = 1.0.0

# uncomment below, if depend on other packages

#Requires: package_name = 1.0.0


%description
# if you want publish current svn URL or Revision use these macros
Lua static library for oceanbase

#%debug_package
# support debuginfo package, to reduce runtime package size

# prepare your files
%install
# OLDPWD is the dir of rpm_create running
# _prefix is an inner var of rpmbuild,
# can set by rpm_create, default is "/home/a"
# _lib is an inner var, maybe "lib" or "lib64" depend on OS

# create dirs
echo %{_to_inc}
echo %{_to_lib}
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/include
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/lib
cd $OLDPWD/../;
rm -rf %{_src}
tar xvf %{_src}.tar.gz
cd %{_src}/src
make a MYCFLAGS=-fPIC
cp %{_to_inc} $RPM_BUILD_ROOT/%{_prefix}/include
cp %{_to_lib} $RPM_BUILD_ROOT/%{_prefix}/lib

# create a crontab of the package
#echo "
#* * * * * root /home/a/bin/every_min
#3 * * * * ads /home/a/bin/every_hour
#" > %{_crontab}

# package infomation
%files 
# set file attribute here
%defattr(-,root,root)
# need not list every file here, keep it as this
%{_prefix}
## create an empy dir

# %dir %{_prefix}/var/log

## need bakup old config file, so indicate here

# %config %{_prefix}/etc/sample.conf

## or need keep old config file, so indicate with "noreplace"

# %config(noreplace) %{_prefix}/etc/sample.conf

## indicate the dir for crontab

# %attr(644,root,root) %{_crondir}/*

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Tue Sep 6 2022 wenxignsen.wxs
- rename ob-lua to devdeps-lua for ob 4.0 opensource
* Mon Apr 12 2021 xuhao.yf
- add spec of ob-lua
