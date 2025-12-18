Name: devdeps-kafka
Version: %(echo $VERSION)
Release: %(echo $RELEASE)%{?dist}
Summary: librdkafka is a C library implementation of the Apache Kafka protocol, providing Producer, Consumer and Admin clients.

Group: oceanbase-devel/dependencies
License: https://github.com/confluentinc/librdkafka/blob/master/LICENSE
URL: https://github.com/confluentinc/librdkafka

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

%define _prefix /usr/local/oceanbase/deps/devel/
%define _src librdkafka-%{version}

%description
librdkafka is a C library implementation of the Apache Kafka protocol, providing Producer, Consumer and Admin clients.

%install
mkdir -p $RPM_BUILD_ROOT/%{_prefix}
export CFLAGS="-fPIC -fstack-protector-strong -I${DEPS_DIR}/include"
export CXXFLAGS="-fPIC -D_GLIBCXX_USE_CXX11_ABI=0 -fstack-protector-strong -I${DEPS_DIR}/include"
export LDFLAGS="-z noexecstack -z now -pie -L${DEPS_DIR}/lib"
export PKG_CONFIG_PATH=${DEPS_DIR}/lib/pkgconfig:$PKG_CONFIG_PATH

CPU_CORES=`grep -c ^processor /proc/cpuinfo`
ROOT_DIR=$OLDPWD/..

cd $ROOT_DIR
rm -rf %{_src}
tar -xf %{_src}.tar.gz
cd %{_src}
mkdir -p tmp_install
if [[ "$USE_LIBCURL" == "1" ]]; then
    ./configure --prefix=${ROOT_DIR}/%{_src}/tmp_install
else
    ./configure --prefix=${ROOT_DIR}/%{_src}/tmp_install --disable-curl
fi
# Only build libraries, skip examples
make -j${CPU_CORES} libs
# Install only libraries, not examples
make install-subdirs

mkdir -p ${RPM_BUILD_ROOT}/%{_prefix}/lib64
cp -r ${ROOT_DIR}/%{_src}/tmp_install/lib/librdkafka.a ${RPM_BUILD_ROOT}/%{_prefix}/lib64
cp -r ${ROOT_DIR}/%{_src}/tmp_install/include ${RPM_BUILD_ROOT}/%{_prefix}/

%files 

%defattr(-,root,root)
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Wed Jun 25 2025 huaixin.lmy
- version kafka 2.12.1