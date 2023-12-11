Name: devdeps-protobuf-c
Version: 1.4.1
Release: %(echo $RELEASE)%{?dist}

Summary: This is protobuf-c, a C implementation of the Google Protocol Buffers data serialization format. 

License:  BSD-2-Clause
Url: https://github.com/protobuf-c/protobuf-c/tree/v1.4.1
AutoReqProv:no

%undefine _missing_build_ids_terminate_build
# disable check-buildroot
%define __arch_install_post %{nil}
%define _buliddir %{_topdir}/BUILD
%define _tmppath %{_buliddir}/_tmp
%define _prefix /usr/local/oceanbase/deps/devel
%define _protobufc protobuf-c-1.4.1
%define _proto protobuf-all-3.20.3
%define _proto_dir protobuf-3.20.3
%define debug_package %{nil}

%description
protobuf-c is a C implementation of the Google Protocol Buffers data serialization format.

%install
mkdir -p %{buildroot}/%{_prefix}/lib/protobuf-c
mkdir -p %{buildroot}/%{_prefix}/include/protobuf-c
cd $OLDPWD/../
rm -rf %{_proto_dir}
tar xf %{_proto}.tar.gz
cd %{_proto_dir}
./configure --prefix=%{_tmppath}/proto
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make -j${CPU_CORES}
make install

cd %{_topdir}/../../
rm -rf %{_protobufc}
tar xf %{_protobufc}.tar.gz
cd %{_protobufc}
export PKG_CONFIG_PATH=%{_tmppath}/proto/lib/pkgconfig
./configure --prefix=%{_tmppath} --enable-shared=yes CFLAGS="-g -O2 -fPIC" CXXFLAGS="-g -O2 -fPIC"
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