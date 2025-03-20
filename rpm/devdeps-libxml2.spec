##############################################################
# http://baike.corp.taobao.com/index.php/%E6%B7%98%E5%AE%9Drpm%E6%89%93%E5%8C%85%E8%A7%84%E8%8C%83 #
# http://www.rpm.org/max-rpm/ch-rpm-inside.html              #
##############################################################
Name: devdeps-libxml2
Version: 2.13.6
Release: %(echo $RELEASE)%{?dist}
# if you want use the parameter of rpm_create on build time,
# uncomment below
Summary: The libxml2 package contains libraries and utilities used for parsing XML files. This package is known to build and work properly using an LFS-10.1 platform.
Group: Development/Tools
License: Commercial
Url: http://www.linuxfromscratch.org/blfs/view/svn/general/libxml2.html

%define _prefix /usr/local/oceanbase/deps/devel
%define _src libxml2-%{version}
# disable check-buildroot
%define __arch_install_post %{nil}
%define __strip /bin/true
%define __os_install_post %{nil}
%define debug_package %{nil}


# uncomment below, if your building depend on other packages

#BuildRequires: package_name = 1.0.0

# uncomment below, if depend on other packages

#Requires: package_name = 1.0.0


%description
# if you want publish current svn URL or Revision use these macros
Complete rewrite of the NASM assembler
CodeUrl:%{_source_path}
CodeRev:%{_source_revision}

%debug_package
# support debuginfo package, to reduce runtime package size

# prepare your files
%install
# OLDPWD is the dir of rpm_create running
# _prefix is an inner var of rpmbuild,
# can set by rpm_create, default is "/home/a"
# _lib is an inner var, maybe "lib" or "lib64" depend on OS

# create dirs
mkdir -p $RPM_BUILD_ROOT/%{_prefix}
cd $OLDPWD/../;
rm -rf %{_src}
tar xvf %{_src}.tar.xz
cd %{_src}
./configure --prefix=${RPM_BUILD_ROOT}/%{_prefix} --without-python --with-pic=yes --enable-static=yes --enable-shared=no
make %{_smp_mflags}; 
make install;
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
* Mon Mar 17 2025 huaixin.lmy
- upgrade to 2.13.6
* Mon Nov 14 2022 xuhao.yf
- upgrade to 2.10.3 to fix CVE Security Vulnerability
* Tue Sep 6 2022 wenxignsen.wxs
- rename ob-libxml2 to devdeps-libxml2 for ob 4.0 opensource
* Mon Mar 1 2021 jiyu.hyx
- add spec of libxml2
