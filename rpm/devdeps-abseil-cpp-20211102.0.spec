Name: %(echo devdeps-abseil-cpp$ABI_FLAG)
Version: 20211102.0
Release: %(echo $RELEASE)%{?dist}
Summary: Abseil is an open-source collection of C++ code (compliant to C++14) designed to augment the C++ standard library.

Group: oceanbase-devel/dependencies
License: Apache 2.0
URL: https://github.com/abseil/abseil-cpp

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat
# disable check-buildroot
%define __arch_install_post %{nil}
# support debuginfo package, to reduce runtime package size
%define debug_package %{nil}

%define _prefix /usr/local/oceanbase/deps/devel
%define _src abseil-cpp-%{version}

%description
The s2geometry-0.10.0 version depends on Abseil.

%install
mkdir -p $RPM_BUILD_ROOT/%{_prefix}
export CFLAGS="-fPIC -fstack-protector-strong"
export CXXFLAGS="${ABI_CXXFLAGS} -fPIC -fstack-protector-strong"
export LDFLAGS="-pie -z noexecstack -z now"
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
ROOT_DIR=$OLDPWD/..

cd $ROOT_DIR
rm -rf %{_src}
mkdir -p %{_src}
tar zxf %{_src}.tar.gz --strip-components=1 -C %{_src}
cd %{_src}
OS_ARCH="$(uname -m)"
if [ x"${OS_ARCH}" == x"loongarch64" ]; then
    export CFLAGS="${CFLAGS} -mcmodel=large"
    export CXXFLAGS="${CXXFLAGS} -mcmodel=large"
    export LDFLAGS="${LDFLAGS} -mcmodel=large"
    sed -i '48a\
#elif defined(__loongarch__)  // LoongArch 架构\
    return reinterpret_cast<void*>(context->uc_mcontext.__pc);' ./absl/debugging/internal/examine_stack.cc
fi
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=${RPM_BUILD_ROOT}/%{_prefix} -DABSL_BUILD_TESTING=OFF -DABSL_USE_GOOGLETEST_HEAD=ON -DCMAKE_CXX_STANDARD=14 -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo
make -j${CPU_CORES}
make install

%files 

%defattr(-,root,root)
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Thu Dec 19 2024 huaixin.lmy
- version 20211102.0
