Name: obdevtools-cmake
Version: 3.22.1
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

# patch for sw_64 arch
OS_ARCH="$(uname -m)"
if [ "${OS_ARCH}x" = "sw_64x" ]; then
    patch -p0 ./Utilities/KWIML/include/kwiml/abi.h ../sw_64/patch/cmake/abi.patch
fi

./bootstrap --prefix=${RPM_BUILD_ROOT}/%{_prefix} -- -DCMAKE_USE_OPENSSL=ON;
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
* Wed Sep 14 2022 oceanbase
- update to 3.22.1 version
* Fri May 7 2021 oceanbase
- add spec of cmake
