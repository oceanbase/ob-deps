Name: devdeps-re2
Version: 20250812
Release: %(echo $RELEASE)%{?dist}
Summary: RE2 is a fast, safe, thread-friendly alternative to backtracking regular expression engines
License: BSD-3-Clause
Url: https://github.com/google/re2
AutoReqProv:no
%undefine _missing_build_ids_terminate_build
%define _build_id_links compat
%define _prefix /usr/local/oceanbase/deps/devel
%define _src re2-2025-08-12

%description
RE2 is a fast, safe, thread-friendly alternative to backtracking regular expression engines.
RE2 depends on Abseil 20250814.1 or newer.

Requires: devdeps-abseil-cpp >= 20250814.1

%define debug_package %{nil}

%install
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/lib/re2
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/include/re2

CPU_CORES=`grep -c ^processor /proc/cpuinfo`

# Use installed abseil (DEP_DIR should have abseil 20250814.1)
abseil_install_dir=${DEP_DIR:-%{_prefix}}
echo "Using external abseil from: $abseil_install_dir"

# prepare re2
cd $OLDPWD/../
rm -rf %{_src}
tar xf %{_src}.tar.gz
pwd
cd %{_src}
source_dir=$(pwd)
tmp_install_dir=${source_dir}/tmp_install_dir
build_dir=${source_dir}/build
rm -rf ${tmp_install_dir}
rm -rf ${build_dir}
mkdir -p ${tmp_install_dir}
mkdir -p ${build_dir}

# compile and install re2
cd ${build_dir}
cmake -DRE2_TEST=OFF \
      -DRE2_BENCHMARK=OFF \
      -DBUILD_SHARED_LIBS=OFF \
      -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
      -DCMAKE_PREFIX_PATH=${abseil_install_dir} \
      -DCMAKE_INSTALL_PREFIX=${tmp_install_dir} \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_C_FLAGS_RELEASE="-O3 -DNDEBUG" \
      -DCMAKE_CXX_FLAGS_RELEASE="-O3 -DNDEBUG" \
      -S .. -B .
make -j${CPU_CORES}
make install

# install re2 files
cp ${tmp_install_dir}/lib/libre2.a $RPM_BUILD_ROOT/%{_prefix}/lib/re2/ 2>/dev/null || cp ${tmp_install_dir}/lib64/libre2.a $RPM_BUILD_ROOT/%{_prefix}/lib/re2/ 2>/dev/null || true
cp -r ${tmp_install_dir}/include/re2/* $RPM_BUILD_ROOT/%{_prefix}/include/re2/

%files
%defattr(-,root,root)
%{_prefix}/lib/re2/libre2.a
%{_prefix}/include/re2/*.h
%exclude %dir %{_prefix}
%exclude %dir %{_prefix}/include
%exclude %dir %{_prefix}/lib
%exclude %dir %{_prefix}/include/re2
%exclude %dir %{_prefix}/lib/re2

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Wed Apr 08 2026 zongmei.zzm <zongmei.zzm@example.com>
- auto-download cmake 3.22.1 if system cmake < 3.16 required by re2
* Wed Apr 01 2026 zongmei.zzm <zongmei.zzm@example.com>
- require external abseil >= 20250814.1, remove bundled abseil
* Sun Mar 09 2025 zongmei.zzm
- initial version 2025.08.12 (upstream 2025-08-12) with abseil 20250814.1
