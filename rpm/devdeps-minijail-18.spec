Name: devdeps-libminijail
Version: %(echo $VERSION)
Release: %(echo $RELEASE)%{?dist}
Summary: Minijail sandboxing tool and libcap dependency for OceanBase development

Url: https://github.com/google/minijail/tree/linux-v18
Group: oceanbase-devel/dependencies
License: BSD-3-Clause

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat

# Disable check-buildroot
%define __arch_install_post %{nil}
%define debug_package %{nil}
%define __strip /bin/true

%define _prefix /usr/local/oceanbase/deps/devel
%define _src minijail-linux-v%{version}
%define _libcap libcap-2.48
%define _buliddir %{_topdir}/BUILD
%define _tmppath %{_buliddir}/_tmp

%description
Minijail is a sandboxing and containment tool used in ChromeOS and Android.
This package includes libminijail and libcap as static libraries (.a) to 
support self-contained deployment of OceanBase.

%build
# Use -fPIC for static libraries. Removed -pie as it is only for executables.
export CFLAGS="-fPIC -z noexecstack -z now -fstack-protector-strong"
export CXXFLAGS="-fPIC -D_GLIBCXX_USE_CXX11_ABI=0 -z noexecstack -z now -fstack-protector-strong"

CPU_CORES=`grep -c ^processor /proc/cpuinfo`

# Prepare temporary directories for internal linking
rm -rf %{_tmppath}
mkdir -p %{_tmppath}/lib64
mkdir -p %{_tmppath}/include/sys

# 1. Build libcap (Static)
cd $OLDPWD/../
rm -rf %{_src}
tar -xf %{_src}.tar.gz
cd %{_src}
tar -xf ../%{_libcap}.tar.gz
cd %{_libcap}

# We enter the 'libcap' subdirectory to build the static library specifically
# SHARED=no prevents building .so files

make -C libcap libcap.a -j${CPU_CORES} CFLAGS="$CFLAGS" SHARED=no GOLANG=no PAM_CAP=no

# Artifacts for libcap 2.48
cp libcap/include/sys/capability.h %{_tmppath}/include/sys/
cp libcap/libcap.a %{_tmppath}/lib64/
cd ..

# 2. Build libminijail (Static)

# Tell the compiler to look for libcap headers and library in our temp directory
export CPATH="%{_tmppath}/include"
export LIBRARY_PATH="%{_tmppath}/lib64"

# Build the Position Independent Code (PIC) version of the static library

make -j${CPU_CORES} "CC_STATIC_LIBRARY(libminijail.pic.a)"

# Store minijail artifacts
cp libminijail.pic.a %{_tmppath}/lib64/libminijail.a
cp libminijail.h %{_tmppath}/include/

%install
# Create target directories
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/lib64
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/include/sys

# Install libraries and headers
cp %{_tmppath}/lib64/libcap.a $RPM_BUILD_ROOT/%{_prefix}/lib64/
cp %{_tmppath}/lib64/libminijail.a $RPM_BUILD_ROOT/%{_prefix}/lib64/
cp %{_tmppath}/include/libminijail.h $RPM_BUILD_ROOT/%{_prefix}/include/
cp %{_tmppath}/include/sys/capability.h $RPM_BUILD_ROOT/%{_prefix}/include/sys/

%files
%defattr(-,root,root)
%{_prefix}/lib64/libcap.a
%{_prefix}/lib64/libminijail.a
%{_prefix}/include/libminijail.h
%{_prefix}/include/sys/capability.h

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Wed Jan 21 2026 oceanbase
- Fix libcap build path and remove -pie from library CFLAGS
- Add libminijail v18 with static libcap v2.48 dependency