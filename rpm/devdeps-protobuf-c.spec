Name: devdeps-protobuf-c
Version: 1.5.1
Release: %(echo $RELEASE)%{?dist}

Summary: This is protobuf-c, a C implementation of the Google Protocol Buffers data serialization format. 

License:  BSD-2-Clause
Url: https://github.com/protobuf-c/protobuf-c/
AutoReqProv:no

%undefine _missing_build_ids_terminate_build
# disable check-buildroot
%define __arch_install_post %{nil}
%define _buliddir %{_topdir}/BUILD
%define _tmppath %{_buliddir}/_tmp
%define _prefix /usr/local/oceanbase/deps/devel
%define _protobufc protobuf-c-%{version}
%define _proto protobuf-all-3.20.3
%define _proto_dir protobuf-3.20.3
%define debug_package %{nil}

%description
protobuf-c is a C implementation of the Google Protocol Buffers data serialization format.

%install
mkdir -p %{buildroot}/%{_prefix}/lib/protobuf-c
mkdir -p %{buildroot}/%{_prefix}/include/protobuf-c
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
sed -i "s|^\(libdir=\).*$|\1'${TOOLS_DIR}/lib64/'|" ${TOOLS_DIR}/lib64/libstdc++.la
export CPPFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0"

# build protobuf-all
cd $OLDPWD/../
rm -rf %{_proto_dir}
tar xf %{_proto}.tar.gz
cd %{_proto_dir}
./configure --prefix=%{_tmppath}/proto
make -j${CPU_CORES}
make install

# build protobuf-c
cd %{_topdir}/../../
rm -rf %{_protobufc}
tar xf %{_protobufc}.tar.gz
cd %{_protobufc}
export PKG_CONFIG_PATH=%{_tmppath}/proto/lib/pkgconfig
export LDFLAGS="-pie -z noexecstack -z now"
export CFLAGS="-fPIC -g -O2 -pie -fstack-protector-strong"
export CXXFLAGS="-fPIC -g -O2 -pie -fstack-protector-strong"
./autogen.sh && ./configure --prefix=%{_tmppath} --enable-shared=yes
make -j${CPU_CORES}
make install

cp %{_tmppath}/include/protobuf-c/*.h %{buildroot}/%{_prefix}/include/protobuf-c
cp %{_tmppath}/lib/*.a %{buildroot}/%{_prefix}/lib/

%files

%defattr(-,root,root)

%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Thu Oct 19 2023 oceanbase
- protobufc 1.4.1