Name: devdeps-grpc
Version: 1.46.7
Release: %(echo $RELEASE)%{?dist}
Url: https://github.com/grpc/grpc
Summary: gRPC is a modern, open source, high-performance remote procedure call (RPC) framework that can run anywhere.

Group: oceanbase-devel/dependencies
License: ASL 2.0 and MIT and BSD

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat

# disable check-buildroot
%define __arch_install_post %{nil}

%define _prefix /usr/local/oceanbase/deps/devel
%define _src grpc-%{version}

%define debug_package %{nil}
%define __strip /bin/true


%description
gRPC is a modern, open source, high-performance remote procedure call (RPC) framework that can run anywhere.

%install

mkdir -p $RPM_BUILD_ROOT/%{_prefix}
cd $OLDPWD/../;
rm -rf %{_src}
tar xvf %{_src}.tar.gz
cd %{_src}

# # If you are building gRPC < 1.27 or if you are using CMake < 3.13 you will need to select "package" mode (rather than "module" mode) for the dependencies.
# # This means you will need to have external copies of these libraries available on your system.
# # ref: https://github.com/grpc/grpc/blob/v1.21.0/test/distrib/cpp/run_distrib_test_cmake.sh

export CFLAGS="-fPIC -z noexecstack -z now -pie -fstack-protector-strong"
export CXXFLAGS="-fPIC  -D_GLIBCXX_USE_CXX11_ABI=0 -z noexecstack -z now -pie -fstack-protector-strong"

# Install c-ares
cd third_party/cares/cares
# git fetch origin
# git checkout cares-1_15_0
mkdir -p cmake/build
cd cmake/build
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX=${RPM_BUILD_ROOT}/%{_prefix} -DCARES_STATIC=ON -DCARES_SHARED=OFF -DCARES_STATIC_PIC=ON -DOPENSSL_ROOT_DIR=${OPENSSL_DIR} ../..
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make -j${CPU_CORES} install
cd ../../../../..
rm -rf third_party/cares/cares  # wipe out to prevent influencing the grpc build

# Install protobuf
cd third_party/protobuf
mkdir -p cmake/build
cd cmake/build
cmake -Dprotobuf_BUILD_TESTS=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX=${RPM_BUILD_ROOT}/%{_prefix} ..
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make -j${CPU_CORES} install
cd ../../../..
rm -rf third_party/protobuf  # wipe out to prevent influencing the grpc build

mkdir -p cmake/build
cd cmake/build
cmake ../.. -DgRPC_INSTALL=ON                \
            -DCMAKE_BUILD_TYPE=RelWithDebInfo	\
            -DgRPC_BUILD_TESTS=OFF           \
            -DgRPC_PROTOBUF_PROVIDER=package  \
            -DgRPC_ZLIB_PROVIDER=package      \
            -DgRPC_CARES_PROVIDER=package     \
            -DgRPC_SSL_PROVIDER=package       \
            -DCMAKE_INSTALL_PREFIX=${RPM_BUILD_ROOT}/%{_prefix} \
            -DBUILD_SHARED_LIBS=OFF
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make -j${CPU_CORES} install

if [ "$SEEKDB_USE" = "1" ]; then
    mv ${RPM_BUILD_ROOT}/%{_prefix}/lib ${RPM_BUILD_ROOT}/%{_prefix}/grpc_lib
    mv ${RPM_BUILD_ROOT}/%{_prefix}/lib64 ${RPM_BUILD_ROOT}/%{_prefix}/grpc_lib64
    mkdir -p ${RPM_BUILD_ROOT}/%{_prefix}/lib/grpc
    mkdir -p ${RPM_BUILD_ROOT}/%{_prefix}/lib64/grpc
    cp -r ${RPM_BUILD_ROOT}/%{_prefix}/grpc_lib/* ${RPM_BUILD_ROOT}/%{_prefix}/lib/grpc
    cp -r ${RPM_BUILD_ROOT}/%{_prefix}/grpc_lib64/* ${RPM_BUILD_ROOT}/%{_prefix}/lib64/grpc
    rm -rf ${RPM_BUILD_ROOT}/%{_prefix}/grpc_lib
    rm -rf ${RPM_BUILD_ROOT}/%{_prefix}/grpc_lib64
fi

%files

%defattr(-,root,root)
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Mon Apr 12 2021 oceanbase
- add spec of grpc
