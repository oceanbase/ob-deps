Name: devdeps-abseil-cpp
Version: 20250814.1
Release: %(echo $RELEASE)%{?dist}
Summary: Abseil is an open-source collection of C++ library code designed to augment the C++ standard library
Group: oceanbase-devel/dependencies
License: Apache-2.0
Url: https://github.com/abseil/abseil-cpp
AutoReqProv: no
%undefine _missing_build_ids_terminate_build
%define _build_id_links compat

%define _prefix /usr/local/oceanbase/deps/devel
%define _src abseil-cpp-%{version}
%define debug_package %{nil}

%description
Abseil is an open-source collection of C++ library code designed to augment the C++ standard library.
The Abseil library code is collected from Google's own C++ code base.

%install
mkdir -p $RPM_BUILD_ROOT/%{_prefix}
export CFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0 -fPIC -pie -fstack-protector-strong"
export CXXFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0 -fPIC -pie -fstack-protector-strong"
export LDFLAGS="-pie -z noexecstack -z now"
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
ROOT_DIR=$OLDPWD/..

cd $ROOT_DIR
rm -rf %{_src}
mkdir -p %{_src}
tar zxf %{_src}.tar.gz --strip-components=1 -C %{_src}
cd %{_src}

mkdir -p build && cd build
cmake -DCMAKE_INSTALL_PREFIX=%{_prefix} \
      -DABSL_ENABLE_INSTALL=ON \
      -DCMAKE_CXX_STANDARD=17 \
      -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_C_FLAGS_RELEASE="-O3 -DNDEBUG" \
      -DCMAKE_CXX_FLAGS_RELEASE="-O3 -DNDEBUG" \
      ..
make -j${CPU_CORES}
make install DESTDIR=$RPM_BUILD_ROOT

%files
%defattr(-,root,root)
%{_prefix}/lib64/libabsl_*.a
%{_prefix}/lib64/cmake/absl
%{_prefix}/lib64/pkgconfig/absl_*.pc
%{_prefix}/include/absl

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Wed Apr 01 2026 zongmei.zzm
- upgrade abseil to 20250814.1 for re2 dependency
