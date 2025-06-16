Name: obdevtools-gdb
Version: %(echo $VERSION)
Release: %(echo $RELEASE)%{?dist}

Summary: The GNU Compiler Collection
Group: oceanbase-devel/tools

License: GPL

Url: https://sourceware.org/gdb/
AutoReqProv:no

# disable check-buildroot
%define __arch_install_post %{nil}

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat

%define _prefix /usr/local
%define _gdb_src gdb-%{version}

%description
GDB, the GNU Project debugger, allows you to see what is going on `inside' another program while it executes -- or what another program was doing at the moment it crashed.

%define debug_package %{nil}

%install
cd $OLDPWD/../; 
rm -rf %{_gdb_src}
tar -xf %{_gdb_src}.tar.xz
source_dir=$(pwd)
tmp_dir=${source_dir}/install
rm -rf ${tmp_dir} && mkdir -p ${tmp_dir}
CPU_CORES=`grep -c ^processor /proc/cpuinfo`

cd ${source_dir}/%{_gdb_src}
mkdir -p build && cd build
LDFLAGS="-static-libgcc -static-libstdc++" ../configure --prefix=${tmp_dir}
make -j${CPU_CORES}
make install

mkdir -p ${RPM_BUILD_ROOT}/%{_prefix}/lib
cp -r ${tmp_dir}/bin ${RPM_BUILD_ROOT}/%{_prefix}
cp -r ${tmp_dir}/lib/*.a ${RPM_BUILD_ROOT}/%{_prefix}/lib
cp -r ${tmp_dir}/include/gdb ${RPM_BUILD_ROOT}/%{_prefix}

%files

%defattr(-,root,root)
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Mon Jun 9 2025 huaixin.lmy
- gdb 13.2
