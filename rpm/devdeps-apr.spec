##############################################################
# http://baike.corp.taobao.com/index.php/%E6%B7%98%E5%AE%9Drpm%E6%89%93%E5%8C%85%E8%A7%84%E8%8C%83 #
# http://www.rpm.org/max-rpm/ch-rpm-inside.html              #
##############################################################
Name: devdeps-apr
Version: 1.7.5
Release: %(echo $RELEASE)%{?dist}
# if you want use the parameter of rpm_create on build time,
# uncomment below
Summary: apach portal runtime library build for oceanbase
Group: Development/Tools
License: Commercial
Url: https://github.com/yasm/yasm
%define _build_id_links none
%define _prefix /usr/local/oceanbase/deps/devel
%define _src apr-%{version}
%define _util_src apr-util-1.6.3
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

export CPPFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0"
export LDFLAGS="-pie -z noexecstack -z now"

# create dirs
mkdir -p $RPM_BUILD_ROOT/%{_prefix}
cd $OLDPWD/../;
rm -rf %{_src}
tar xf %{_src}.tar.gz
cd %{_src}
./configure --prefix=${RPM_BUILD_ROOT}/%{_prefix};
make %{_smp_mflags}; 
make install;

cd ..;
tar xf %{_util_src}.tar.gz
cd %{_util_src}
./configure --prefix=${RPM_BUILD_ROOT}/%{_prefix} --with-apr=${RPM_BUILD_ROOT}/%{_prefix}
make %{_smp_mflags}; 
make install


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
- rename ob-apr to devdeps-apr for ob 4.0 opensource
* Fri Feb 14 2020 yuanqi.xhf
- add spec of yasm
