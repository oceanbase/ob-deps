Name: obdevtools-ccache
Version: 3.7.12
Release: %(echo $RELEASE)%{?dist}

Summary: Ccache (or "ccache") is a compiler cache.

Url: https://ccache.dev/

Group: oceanbase-devel/tools
License: GPLv3+

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat

# disable check-buildroot
%define __arch_install_post %{nil}

%define _prefix /usr/local/oceanbase/devtools/
%define _src ccache-%{version}
%define debug_package %{nil}

%description
Ccache (or "ccache") is a compiler cache. It speeds up recompilation by caching previous compilations and detecting when the same compilation is being done again.

%build

cd $OLDPWD/../;
rm -rf %{_src}
tar -xf %{_src}.tar.gz
cd %{_src}
./configure --prefix=${RPM_BUILD_ROOT}/%{_prefix} --disable-man
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make -j${CPU_CORES};

%install

mkdir -p $RPM_BUILD_ROOT/%{_prefix}
cd $OLDPWD/../%{_src}
make install;

%files 

%defattr(-,root,root)
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Fri Mar 26 2021 oceanbase
- add spec of ccache 
