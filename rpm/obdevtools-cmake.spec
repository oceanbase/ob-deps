Name: obdevtools-cmake
Version: 3.20.2
Release: %(echo $RELEASE)%{?dist}

Summary: Cross-platform make system

Url: https://cmake.org/

Packager: Ant Group Co., Ltd.
Vendor: Ant Group Co., Ltd.
Group: oceanbase-devel/tools
License: BSD and MIT and zlib

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat

%define _prefix /usr/local/oceanbase/devtools/
%define _src cmake-%{version}
%define debug_package %{nil}

%description
CMake is an open-source, cross-platform family of tools designed to build, test and package software. CMake is used to control the software compilation process using simple platform and compiler independent configuration files, and generate native makefiles and workspaces that can be used in the compiler environment of your choice. The suite of CMake tools were created by Kitware in response to the need for a powerful, cross-platform build environment for open-source projects such as ITK and VTK.

%build

cd $OLDPWD/../
rm -rf %{_src}
tar xf %{_src}.tar.gz
cd %{_src}
./bootstrap --prefix=${RPM_BUILD_ROOT}/%{_prefix} -- -DCMAKE_USE_OPENSSL=OFF;
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make -j${CPU_CORES};

%install

mkdir -p $RPM_BUILD_ROOT/%{_prefix}
cd $OLDPWD/../%{_src}
make install

%files 

%defattr(-,root,root)
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Fri May 7 2021 oceanbase
- add spec of cmake
