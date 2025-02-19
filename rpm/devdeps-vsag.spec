Name: devdeps-vsag	
Version: %(echo $VERSION)	
Release: %(echo $RELEASE)%{?dist}
Summary: VSAG is a vector indexing library used for similarity search.
 
License: GPLv2 or Apache 2.0
URL: https://github.com/alipay/vsag
 
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
mv vsag-0.13.3 %{_default_version_src}
cd %{_default_version_src}
 
export CC=/usr/local/oceanbase/devtools/bin/gcc
export CXX=/usr/local/oceanbase/devtools/bin/g++
export FC=/usr/local/oceanbase/devtools/bin/gfortran

export CFLAGS="-fPIC -fPIE -D_GLIBCXX_USE_CXX11_ABI=0 -fstack-protector-strong"
export CXXFLAGS="-fPIC -fPIE -D_GLIBCXX_USE_CXX11_ABI=0 -fstack-protector-strong"
export LDFLAGS="-z noexecstack -z now -pie"
 
git init
git apply ../patch/vsag.patch
cmake .
 
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make  -j${CPU_CORES}
 
mkdir -p %{buildroot}/%{_prefix}/lib/vsag_lib
mkdir -p %{buildroot}/%{_prefix}/include/vsag
cp ./ob_vsag_lib.h %{buildroot}/%{_prefix}/include/vsag
cp ./ob_vsag_lib_c.h %{buildroot}/%{_prefix}/include/vsag
cp ./include/vsag/logger.h %{buildroot}/%{_prefix}/include/vsag
cp ./include/vsag/allocator.h %{buildroot}/%{_prefix}/include/vsag
cp /usr/local/oceanbase/devtools/lib64/libgfortran.so.5 %{buildroot}/%{_prefix}/lib/vsag_lib/libgfortran.so
cp /usr/local/oceanbase/devtools/lib64/libgfortran.a %{buildroot}/%{_prefix}/lib/vsag_lib/libgfortran_static.a
cp /usr/local/oceanbase/devtools/lib64/libgomp.a %{buildroot}/%{_prefix}/lib/vsag_lib/libgomp_static.a
cp /usr/local/oceanbase/devtools/lib64/libgomp.so %{buildroot}/%{_prefix}/lib/vsag_lib/libgomp.so
cp ./libob_vsag_static.a %{buildroot}/%{_prefix}/lib/vsag_lib
cp ./libob_vsag.so %{buildroot}/%{_prefix}/lib/vsag_lib
cp ./src/libvsag.so %{buildroot}/%{_prefix}/lib/vsag_lib
cp ./src/libvsag_static.a %{buildroot}/%{_prefix}/lib/vsag_lib
cp ./src/simd/libsimd.a %{buildroot}/%{_prefix}/lib/vsag_lib
cp ./_deps/cpuinfo-build/libcpuinfo.a %{buildroot}/%{_prefix}/lib/vsag_lib
cp ./libdiskann.a %{buildroot}/%{_prefix}/lib/vsag_lib
cp ./openblas/install/lib/libopenblas.a %{buildroot}/%{_prefix}/lib/vsag_lib
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
* Thu Sep 26 2024 oceanbase
- vsag-1.0.0
 
