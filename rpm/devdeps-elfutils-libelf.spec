##############################################################
# http://baike.corp.taobao.com/index.php/%E6%B7%98%E5%AE%9Drpm%E6%89%93%E5%8C%85%E8%A7%84%E8%8C%83 #
# http://www.rpm.org/max-rpm/ch-rpm-inside.html              #
##############################################################
Name: devdeps-elfutils-libelf
Version:1.0.2
Release: %(echo $RELEASE)%{?dist}
# if you want use the parameter of rpm_create on build time,
# uncomment below
Summary: elfutils-libelf-devel lets you read, modify or create ELF files in an architecture-independent way
Group: alibaba/application
License: Commercial
%define _prefix /usr/local/oceanbase/deps/devel
%define _src elfutils-0.163
#%define debug_package %{nil}
#%define __strip $OLDPWD/rpm/strip
#%define __strip /usr/bin/strip
%define __strip /bin/true
%global _find_debuginfo_opts -s



# uncomment below, if your building depend on other packages

#BuildRequires: package_name = 1.0.0

# uncomment below, if depend on other packages

#Requires: package_name = 1.0.0


%description
# if you want publish current svn URL or Revision use these macros
elfutils-libelf-devel lets you read, modify or create ELF files in an architecture-independent way
CodeUrl:%{_source_path}
CodeRev:%{_source_revision}

#%debug_package
# support debuginfo package, to reduce runtime package size

# prepare your files
%install
# OLDPWD is the dir of rpm_create running
# _prefix is an inner var of rpmbuild,
# can set by rpm_create, default is "/home/a"
# _lib is an inner var, maybe "lib" or "lib64" depend on OS
#export PATH=/usr/local/gcc-5.2.0/bin:$PATH
mkdir -p $RPM_BUILD_ROOT/%{_prefix}
cd $OLDPWD/..
rm -rf %{_src}
tar xf %{_src}.tar.bz2
cd %{_src}
./configure
cd libelf
make %{_smp_mflags};
mkdir -p tmp
make install DESTDIR=$(pwd)/tmp
mkdir -p ${RPM_BUILD_ROOT}/%{_prefix}/lib/
mkdir -p ${RPM_BUILD_ROOT}/%{_prefix}/include/
cp tmp/usr/local/lib/*.a ${RPM_BUILD_ROOT}/%{_prefix}/lib/
cp $(pwd)/libelf_pic.a ${RPM_BUILD_ROOT}/%{_prefix}/lib/
cp tmp/usr/local/lib/*.so ${RPM_BUILD_ROOT}%{_prefix}/lib/
cp tmp/usr/local/include/*.h ${RPM_BUILD_ROOT}%{_prefix}/include/

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
* Thu Jul 4 2024 wangzelin.wzl
- add spec to ob-deps
* Wed Nov 18 2020 nijia.nj
- add spec of ob-elfutils-libelf
