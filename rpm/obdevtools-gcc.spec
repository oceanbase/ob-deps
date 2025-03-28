Name: obdevtools-gcc
Version: 12.3.0
Release: %(echo $RELEASE)%{?dist}

Summary: The GNU Compiler Collection
Group: oceanbase-devel/tools

License: GPL

Url: https://gcc.gnu.org/
AutoReqProv:no

# disable check-buildroot
%define __arch_install_post %{nil}

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat

%define _prefix /usr/local/oceanbase/devtools/
%define _gcc_src gcc-%{version}
%define _mpc_src mpc-1.2.1
%define _mpfr_src mpfr-4.1.0
%define _isl_src isl-0.24
%define _gmp_src gmp-6.2.1

%description
The GNU Compiler Collection includes front ends for C, C++, Fortran, Lto as well as libraries for these languages (libstdc++,...). GCC was originally written as the compiler for the GNU operating system. The GNU system was developed to be 100% free software, free in the sense that it respects the user's freedom.

%define debug_package %{nil}

%install
cd $OLDPWD/../; 
rm -rf %{_gcc_src}
tar -xf %{_gcc_src}.tar.gz

tar -xf %{_mpc_src}.tar.gz
mv %{_mpc_src} %{_gcc_src}/mpc
tar -xf %{_mpfr_src}.tar.bz2
mv %{_mpfr_src} %{_gcc_src}/mpfr
tar -xf %{_gmp_src}.tar.bz2
mv %{_gmp_src} %{_gcc_src}/gmp
tar -xf %{_isl_src}.tar.bz2
mv %{_isl_src} %{_gcc_src}/isl

cd %{_gcc_src}
arch=$(uname -m)
gcc_build=${arch}-redhat-linux
./configure --enable-bootstrap --enable-languages=c,c++,fortran,lto --prefix=${RPM_BUILD_ROOT}/%{_prefix} --enable-shared --enable-threads=posix --enable-checking=release --disable-multilib --disable-libunwind-exceptions --enable-gnu-unique-object --enable-linker-build-id --with-gcc-major-version-only --with-linker-hash-style=gnu --with-default-libstdcxx-abi=gcc4-compatible --enable-plugin --enable-initfini-array --enable-gnu-indirect-function --build=${gcc_build}

CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make -j${CPU_CORES};
make install;

%files 

%defattr(-,root,root)
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Fri Feb 14 2020 oceanbase
- add spec of gcc
