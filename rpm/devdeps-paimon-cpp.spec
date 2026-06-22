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
DISABLE_ATOMIC=""
arch=`uname -p`
if [ "x$arch" = "xaarch64" ]; then
    DISABLE_ATOMIC="-mno-outline-atomics"
fi
TOOLCHAIN_FLAGS="--gcc-toolchain=${TOOLS_DIR} -B${TOOLS_DIR}/bin"
export CFLAGS="${TOOLCHAIN_FLAGS} -O2 -fPIC ${DISABLE_ATOMIC}"
export CXXFLAGS="${TOOLCHAIN_FLAGS} -O2 -fPIC ${DISABLE_ATOMIC}"
export LDFLAGS="${TOOLCHAIN_FLAGS} -fuse-ld=lld ${DISABLE_ATOMIC} ${LDFLAGS:-}"
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

# arrow 20.0.0 原始 tarball 不含 paimon 定制修改，替换 arrow.diff
/bin/cp -f $ROOT_DIR/patch/paimon-cpp-arrow-20.0.0.diff cmake_modules/arrow.diff

# Disable oneTBB weak-symbol allocator probing for the bundled TBB build.
sed -i 's#set(TBB_CMAKE_CXX_FLAGS "${EP_CXX_FLAGS} -Wno-error")#set(TBB_CMAKE_CXX_FLAGS "${EP_CXX_FLAGS} -Wno-error -D__TBB_WEAK_SYMBOLS_PRESENT=0")#' cmake_modules/ThirdpartyToolchain.cmake
grep -q '__TBB_WEAK_SYMBOLS_PRESENT=0' cmake_modules/ThirdpartyToolchain.cmake

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
         -DPAIMON_BUILD_SHARED=OFF
make -j${CPU_CORES}
make install

mkdir -p $RPM_BUILD_ROOT/%{_prefix}/lib64/paimon_deps
cp ./arrow_ep-install/lib/lib*.a ${RPM_BUILD_ROOT}/%{_prefix}/lib64/paimon_deps/
cp ./avro_ep-install/lib/libavrocpp_s.a ${RPM_BUILD_ROOT}/%{_prefix}/lib64/paimon_deps/
cp ./orc_ep-prefix/lib/liborc.a ${RPM_BUILD_ROOT}/%{_prefix}/lib64/paimon_deps/
cp ./protobuf_ep-install/lib/libprotobuf.a ${RPM_BUILD_ROOT}/%{_prefix}/lib64/paimon_deps/
cp ./snappy_ep-install/lib/libsnappy.a ${RPM_BUILD_ROOT}/%{_prefix}/lib64/paimon_deps/
cp ./zstd_ep-install/lib/libzstd.a ${RPM_BUILD_ROOT}/%{_prefix}/lib64/paimon_deps/
cp ./lz4_ep-install/lib/liblz4.a ${RPM_BUILD_ROOT}/%{_prefix}/lib64/paimon_deps/
cp ./zlib_ep-install/lib/libz.a ${RPM_BUILD_ROOT}/%{_prefix}/lib64/paimon_deps/
cp ./re2_ep-install/lib/libre2.a ${RPM_BUILD_ROOT}/%{_prefix}/lib64/paimon_deps/
cp ./fmt_ep-install/lib/libfmt.a ${RPM_BUILD_ROOT}/%{_prefix}/lib64/paimon_deps/
cp ./glog_ep-install/lib/libglog.a ${RPM_BUILD_ROOT}/%{_prefix}/lib64/paimon_deps/
cp ./tbb_ep-install/lib/libtbb.a ${RPM_BUILD_ROOT}/%{_prefix}/lib64/paimon_deps/
cp ./tbb_ep-install/lib/libtbbmalloc.a ${RPM_BUILD_ROOT}/%{_prefix}/lib64/paimon_deps/
cp ./relwithdebinfo/libroaring_bitmap.a ${RPM_BUILD_ROOT}/%{_prefix}/lib64/paimon_deps/

bash "$ROOT_DIR/patch/paimon-cpp-private-repack.sh" \
  "${RPM_BUILD_ROOT}/%{_prefix}/lib64" \
  "${RPM_BUILD_ROOT}/%{_prefix}/lib64/paimon_deps"

%files

%defattr(-,root,root)
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Thu Apr 30 2026 OceanBase Deps
- link shared libs with -static-libstdc++ -static-libgcc for portable libstdc++/libgcc

* Fri Mar 27 2026 OceanBase Deps
- initial devdeps-paimon-cpp 0.1.1
