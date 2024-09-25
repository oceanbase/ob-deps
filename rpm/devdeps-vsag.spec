Name: devdeps-vsag
Version: %(echo $VERSION)
Release: %(echo $RELEASE)%{?dist}

Summary: A library that provides fast ann query algorithm.

License: GPLv2 or Apache 2.0
Url: https://github.com/facebook/rocksdb
AutoReqProv:no

%undefine _missing_build_ids_terminate_build
%define _prefix /usr/local/oceanbase/deps/devel
%define _vsag_src vsag-%{version}
%define debug_package %{nil}
%define _default_version_src vsag-1.0.0
%define _gcc_path /usr/local/oceanbase/devtools/bin
%define _install_prefix ./install
%description
A library that provides fast ann query algorithm.

%install
mkdir -p %{buildroot}/%{_prefix}
cd $OLDPWD/../
rm -rf %{_vsag_src}

tar xf %{_vsag_src}.tar.gz 
tar -xf vsag_third_party.tar.gz
mv ob-vsag %{_default_version_src}
cd %{_default_version_src}

export PATH=/usr/local/oceanbase/devtools/bin:$PATH
export CC=/usr/local/oceanbase/devtools/bin/gcc
export CXX=/usr/local/oceanbase/devtools/bin/g++
export FC=/usr/local/oceanbase/devtools/bin/gfortran
export LD_LIBRARY_PATH=/usr/local/oceanbase/devtools/lib64

mkdir -p ./_deps/vsag-subbuild/vsag-populate-prefix/src
cp ../vsag_third_party/v0.11.2.tar.gz ./_deps/vsag-subbuild/vsag-populate-prefix/src/
mkdir -p ./_deps/vsag-build/hdf5/src/
cp ../vsag_third_party/hdf5_1.14.4.tar.gz ./_deps/vsag-build/hdf5/src/hdf5_1.14.4.tar.gz
mkdir -p ./_deps/pybind11-subbuild/pybind11-populate-prefix/src/
cp ../vsag_third_party/v2.11.1.tar.gz ./_deps/pybind11-subbuild/pybind11-populate-prefix/src/v2.11.1.tar.gz
mkdir -p ./_deps/thread_pool-subbuild/thread_pool-populate-prefix/src/
cp ../vsag_third_party/master.tar.gz ./_deps/thread_pool-subbuild/thread_pool-populate-prefix/src/master.tar.gz
mkdir -p ./_deps/vsag-build/spdlog/src/
cp ../vsag_third_party/v1.12.0.tar.gz ./_deps/vsag-build/spdlog/src/spdlog-1.12.0.tar.gz
mkdir -p ./_deps/nlohmann_json-subbuild/nlohmann_json-populate-prefix/src/
cp ../vsag_third_party/v3.11.3.tar.gz ./_deps/nlohmann_json-subbuild/nlohmann_json-populate-prefix/src/v3.11.3.tar.gz
mkdir -p ./_deps/roaringbitmap-subbuild/roaringbitmap-populate-prefix/src/
cp ../vsag_third_party/v3.0.1.tar.gz ./_deps/roaringbitmap-subbuild/roaringbitmap-populate-prefix/src/v3.0.1.tar.gz
mkdir -p ./_deps/fmt-subbuild/fmt-populate-prefix/src/
cp ../vsag_third_party/10.2.1.tar.gz ./_deps/fmt-subbuild/fmt-populate-prefix/src/10.2.1.tar.gz
mkdir -p ./_deps/vsag-build/boost/src/
cp ../vsag_third_party/boost_1_67_0.tar.gz ./_deps/vsag-build/boost/src/boost_1_67_0.tar.gz
mkdir -p ./_deps/catch2-subbuild/catch2-populate-prefix/src
cp ../vsag_third_party/v3.4.0.tar.gz ./_deps/catch2-subbuild/catch2-populate-prefix/src/v3.4.0.tar.gz
mkdir -p ./_deps/vsag-build/openblas/src/
cp ../vsag_third_party/OpenBLAS-0.3.23.tar.gz ./_deps/vsag-build/openblas/src/OpenBLAS-v0.3.23.tar.gz
mkdir -p ./_deps/cpuinfo-subbuild/cpuinfo-populate-prefix/src/
cp ../vsag_third_party/ca678952a9a8eaa6de112d154e8e104b22f9ab3f.tar.gz ./_deps/cpuinfo-subbuild/cpuinfo-populate-prefix/src/ca678952a9a8eaa6de112d154e8e104b22f9ab3f.tar.gz
cmake .


CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make  -j${CPU_CORES}

mkdir -p %{buildroot}/%{_prefix}/lib/vsag_lib
mkdir -p %{buildroot}/%{_prefix}/include/vsag
cp ./ob_vsag_lib.h %{buildroot}/%{_prefix}/include/vsag
cp ./ob_vsag_lib_c.h %{buildroot}/%{_prefix}/include/vsag
cp ./_deps/vsag-src/include/vsag/logger.h %{buildroot}/%{_prefix}/include/vsag
cp ./_deps/vsag-src/include/vsag/allocator.h %{buildroot}/%{_prefix}/include/vsag
cp /usr/local/oceanbase/devtools/lib64/libgfortran.so.5 %{buildroot}/%{_prefix}/lib/vsag_lib/libgfortran.so
cp /usr/local/oceanbase/devtools/lib64/libgfortran.a %{buildroot}/%{_prefix}/lib/vsag_lib/libgfortran_static.a
cp /usr/local/oceanbase/devtools/lib64/libgomp.a %{buildroot}/%{_prefix}/lib/vsag_lib/libgomp_static.a
cp /usr/local/oceanbase/devtools/lib64/libgomp.so %{buildroot}/%{_prefix}/lib/vsag_lib/libgomp.so
cp ./libob_vsag_static.a %{buildroot}/%{_prefix}/lib/vsag_lib
cp ./libob_vsag.so %{buildroot}/%{_prefix}/lib/vsag_lib
cp ./_deps/vsag-build/src/libvsag.so %{buildroot}/%{_prefix}/lib/vsag_lib
cp ./_deps/vsag-build/src/libvsag_static.a %{buildroot}/%{_prefix}/lib/vsag_lib
cp ./_deps/vsag-build/src/simd/libsimd.a %{buildroot}/%{_prefix}/lib/vsag_lib
cp ./_deps/cpuinfo-build/libcpuinfo.a %{buildroot}/%{_prefix}/lib/vsag_lib
cp ./_deps/vsag-build/libdiskann.a %{buildroot}/%{_prefix}/lib/vsag_lib
cp ./_deps/vsag-build/openblas/install/lib/libopenblas.a %{buildroot}/%{_prefix}/lib/vsag_lib
#cp ./_deps/roaringbitmap-build/src/libroaring.a %{buildroot}/%{_prefix}/lib/vsag_lib
arch=$(uname -p)
if [ "$arch" = "x86_64" ]; then
    cp /usr/local/oceanbase/devtools/lib64/libquadmath.so %{buildroot}/%{_prefix}/lib/vsag_lib
    cp /usr/local/oceanbase/devtools/lib64/libquadmath.a %{buildroot}/%{_prefix}/lib/vsag_lib/libquadmath_static.a
fi
%files

%defattr(-,root,root)

%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Mon Feb 28 2022 oceanbase
- vsag-1.0.0

