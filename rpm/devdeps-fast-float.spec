Name: devdeps-fast-float		
Version: 6.1.3
Release: %(echo $RELEASE)%{?dist}
Summary: This is the repository for fast and exact implementation of the C++ from_chars functions for number types.

Group: oceanbase-devel/dependencies
License: Apache-2.0 License or MIT License or BSL-1.0 license
URL: https://github.com/fastfloat/fast_float

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat

# disable check-buildroot
%define __arch_install_post %{nil}

%define _prefix /usr/local/oceanbase/deps/devel
%define _src fast_float-%{version}

%description
The fast_float library provides fast header-only implementations for the C++ from_chars functions
for float and double types as well as integer types.

%install
mkdir -p $RPM_BUILD_ROOT/%{_prefix}
cd $OLDPWD/../;
rm -rf %{_src}
tar xvf %{_src}.tar.gz
cd %{_src}
mkdir -p cmake/build
cd cmake/build
cmake ../.. -DFASTFLOAT_TEST=ON \
		-DCMAKE_BUILD_TYPE=RelWithDebInfo \
		-DCMAKE_INSTALL_PREFIX=${RPM_BUILD_ROOT}/%{_prefix} \
		-DBUILD_SHARED_LIBS=OFF
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make -j${CPU_CORES} install

%files

%defattr(-,root,root)
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Mon Nov 4 2024 oceanbase
- add spec of fast-float
