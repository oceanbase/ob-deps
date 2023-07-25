Name: obdevtools-gcc
Version: 5.2.0
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
%define _mpc_src mpc-0.8.1
%define _mpfr_src mpfr-2.4.2
%define _isl_src isl-0.14
%define _gmp_src gmp-4.3.2
%define _buliddir %{_topdir}/BUILD
%define _tmppath %{_buliddir}/_tmp


%description
The GNU Compiler Collection includes front ends for C, C++, Fortran, Lto as well as libraries for these languages (libstdc++,...). GCC was originally written as the compiler for the GNU operating system. The GNU system was developed to be 100% free software, free in the sense that it respects the user's freedom.

%debug_package

%install
cd $OLDPWD/../; 
rm -rf %{_gcc_src}
tar -xf %{_gcc_src}.tar.gz

# preinstall gmp
rm -rf %{_gmp_src}
tar -xf %{_gmp_src}.tar.bz2
cd %{_gmp_src}
./configure --disable-shared --enable-static --build=unknown-unknown-linux --prefix=%{_tmppath}
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make -j${CPU_CORES};
make install
cd ..

# preinstall mpfr
rm -rf %{_mpfr_src}
tar -xf %{_mpfr_src}.tar.bz2
cd %{_mpfr_src}
./configure --disable-shared --enable-static --prefix=%{_tmppath} --build=unknown-unknown-linux --with-gmp=%{_tmppath}
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make -j${CPU_CORES};
make install
cd ..

# preinstall mpc
rm -rf %{_mpc_src} 
tar -xf %{_mpc_src}.tar.gz
cd %{_mpc_src} 
./configure --disable-shared --enable-static --build=unknown-unknown-linux --prefix=%{_tmppath} --with-gmp=%{_tmppath} --with-mpfr=%{_tmppath}
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make -j${CPU_CORES};
make install
cd ..

# preinstall isl
rm -rf %{_isl_src}
tar -xf %{_isl_src}.tar.bz2
cd %{_isl_src}
./configure --disable-shared --enable-static --prefix=%{_tmppath} --with-gmp-prefix=%{_tmppath}
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make -j${CPU_CORES};
make install
cd ..

# install gcc
cd %{_gcc_src}
./configure --enable-bootstrap --enable-languages=c,c++,fortran,lto --prefix=${RPM_BUILD_ROOT}/%{_prefix} --enable-shared --enable-threads=posix --enable-checking=release --disable-multilib --disable-libunwind-exceptions --enable-gnu-unique-object --enable-linker-build-id --with-gcc-major-version-only --with-linker-hash-style=gnu --with-default-libstdcxx-abi=gcc4-compatible --enable-plugin --enable-initfini-array --enable-gnu-indirect-function --with-gmp=%{_tmppath} --with-mpfr=%{_tmppath} --with-mpc=%{_tmppath} --with-isl=%{_tmppath} --build=aarch64-redhat-linux
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
