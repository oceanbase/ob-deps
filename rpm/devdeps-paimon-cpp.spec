Name: %(echo devdeps-paimon-cpp$ABI_FLAG)
Version: %(echo $VERSION)
Release: %(echo $RELEASE)%{?dist}
Summary: Alibaba Paimon C++ client library and dependencies

Group: oceanbase-devel/dependencies
License: Apache-2.0
URL: https://github.com/alibaba/paimon-cpp

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat
%define __arch_install_post %{nil}
%define debug_package %{nil}
%define _prefix /usr/local/oceanbase/deps/devel
%define _src paimon-cpp-%{version}

%description
Paimon C++ library built for OceanBase devdeps (Ninja, old C++11 ABI, Jindo disabled).

%install
mkdir -p $RPM_BUILD_ROOT/%{_prefix}

# _FORTIFY_SOURCE (often from rpmbuild) requires -O; third_party TBB etc. inherit these flags
export CFLAGS="-O2 -fPIC -z noexecstack -z now -pie -fstack-protector-strong"
export CXXFLAGS="-O2 -fPIC -z noexecstack -z now -pie -fstack-protector-strong"
export CPPFLAGS="${ABI_CXXFLAGS}"
CPU_CORES=8
ROOT_DIR=$OLDPWD/..

cd $ROOT_DIR
rm -rf %{_src}
mkdir -p %{_src}
tar zxf %{_src}.tar.gz --strip-components=1 -C %{_src}
cd %{_src}

# Drop Jindo SDK download (Aliyun-only tarball); CMake keeps PAIMON_ENABLE_JINDO=OFF
grep -v 'PAIMON_JINDOSDK' third_party/versions.txt > third_party/versions.txt.tmp
mv -f third_party/versions.txt.tmp third_party/versions.txt

# Offline: place third_party.tar.gz next to paimon-cpp-*.tar.gz ($ROOT_DIR); else download
if [ -f "$ROOT_DIR/third_party.tar.gz" ]; then
  tar -xf "$ROOT_DIR/third_party.tar.gz" --strip-components=1 -C third_party/
else
  bash third_party/download_dependencies.sh
fi

rm -rf build && mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=${RPM_BUILD_ROOT}/%{_prefix} \
         -DCMAKE_BUILD_TYPE=RelWithDebInfo \
         -DPAIMON_USE_CXX11_ABI=OFF \
         -DPAIMON_BUILD_TESTS=OFF \
         -DPAIMON_ENABLE_JINDO=OFF \
         -DPAIMON_BUILD_STATIC=ON \
         -DPAIMON_BUILD_SHARED=ON
make -j${CPU_CORES}
make install

%files

%defattr(-,root,root)
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Fri Mar 27 2026 OceanBase Deps
- initial devdeps-paimon-cpp 0.1.1
