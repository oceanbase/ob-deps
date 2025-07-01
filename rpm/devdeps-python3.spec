Name: devdeps-python3
Version: %(echo $VERSION)
Release: %(echo $RELEASE)%{?dist}
Summary: Python is a programming language that lets you work quickly and integrate systems more effectively.

Group: oceanbase-devel/dependencies
License: https://docs.python.org/3/license.html#python-software-foundation-license-version-2
URL: https://www.python.org/downloads/source/

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat
# disable check-buildroot
%define __arch_install_post %{nil}
# support debuginfo package, to reduce runtime package size
%define debug_package %{nil}
# disable modify shebang
%global __brp_mangle_shebangs %{nil}
# disable strip debuginfo and rpath
%global __os_install_post %{nil}

%define _prefix /usr/local/oceanbase/deps/devel/python3
%define _src Python-%{version}

%description
Python is a programming language that lets you work quickly and integrate systems more effectively.

%install
mkdir -p $RPM_BUILD_ROOT/%{_prefix}
export CFLAGS="-fPIC -fPIE -D_GLIBCXX_USE_CXX11_ABI=0 -fstack-protector-strong"
export CXXFLAGS="-fPIC -fPIE -D_GLIBCXX_USE_CXX11_ABI=0 -fstack-protector-strong"
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
ROOT_DIR=$OLDPWD/..

cd $ROOT_DIR
rm -rf %{_src}
tar -xf %{_src}.tgz
cd %{_src}
mkdir build && cd build
export PROFILE_TASK="-m test --pgo -i test_generators --timeout="
LDFLAGS='-z noexecstack -z now -Wl,-rpath,\$$ORIGIN/../lib' ../configure --prefix=${RPM_BUILD_ROOT}/%{_prefix} --enable-shared --enable-optimizations --disable-test-modules --without-ensurepip --with-lto

make -j${CPU_CORES}
make install

arch=$(uname -p)
rm ${RPM_BUILD_ROOT}/%{_prefix}/lib/python3.13/config-3.13-${arch}-linux-gnu/libpython3.13.a
cd ${RPM_BUILD_ROOT}/%{_prefix}/bin/
ln -s python3 python

%files 

%defattr(-,root,root)
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Wed Jun 25 2025 huaixin.lmy
- version python 3.13.3