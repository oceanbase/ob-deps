Name: obdevtools-binutils
Version: 2.30
Release: %(echo $RELEASE)%{?dist}

Summary: The GNU Binutils are a collection of binary tools. 

Url: https://www.gnu.org/software/binutils/
Group: oceanbase-devel/tools
License: GPLv3+

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat

# disable check-buildroot
%define __arch_install_post %{nil}

%define _prefix /usr/local/oceanbase/devtools/
%define _src binutils-%{version}
%define debug_package %{nil}

%description
The GNU Binutils are a collection of binary tools. The main ones are:ld, as. But they also include: addr2line, ar, c++filt, dlltool, gold, gprof, nlmconv, nm, objcopy, objdump, ranlib, readelf, size, strings, strip, windmc, windres

%build

cd $OLDPWD/../
rm -rf %{_src} 
tar xf %{_src}.tar.bz2
cd %{_src}
./configure --prefix=${RPM_BUILD_ROOT}/%{_prefix} --enable-install-libiberty
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make -j${CPU_CORES};

%install

mkdir -p $RPM_BUILD_ROOT/%{_prefix}
cd $OLDPWD/../%{_src}
make install

%files 

%defattr(-,root,root)
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Fri Mar 26 2021 oceanbase
- add spec of binutils
