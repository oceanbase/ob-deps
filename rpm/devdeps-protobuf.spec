Name: %(echo devdeps-protobuf$ABI_FLAG)
Version: 3.19.5
Release: %(echo $RELEASE)%{?dist}
Url: https://github.com/protocolbuffers/protobuf
Summary: Protocol Buffers - Google's data interchange format

Group: oceanbase-devel/dependencies
License: BSD

AutoReqProv:no
%undefine _missing_build_ids_terminate_build
%define _build_id_links compat

# disable check-buildroot
%define __arch_install_post %{nil}

%define _prefix /usr/local/oceanbase/deps/devel
%define _src protobuf-%{version}

%define debug_package %{nil}
%define __strip /bin/true

%description
Protocol Buffers (a.k.a., protobuf) are Google's language-neutral,
platform-neutral, extensible mechanism for serializing structured data.

%install

mkdir -p $RPM_BUILD_ROOT/%{_prefix}
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
cd $OLDPWD/../;
rm -rf %{_src}
tar xf protobuf-all-%{version}.tar.gz
cd %{_src}

export CPPFLAGS="${ABI_CXXFLAGS}"
export CFLAGS="-fPIC -z noexecstack -z now -pie -fstack-protector-strong"
export CXXFLAGS="-fPIC -z noexecstack -z now -pie -fstack-protector-strong"

mkdir -p cmake/build
cd cmake/build
cmake -Dprotobuf_BUILD_TESTS=OFF \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DBUILD_SHARED_LIBS=OFF \
      -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
      -DCMAKE_INSTALL_PREFIX=${RPM_BUILD_ROOT}/%{_prefix} \
      ..
make -j${CPU_CORES} install

%files

%defattr(-,root,root)
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Thu Mar 13 2026 oceanbase
- add spec of protobuf, split from grpc and apache-orc builds
