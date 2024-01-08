Name: devdeps-isa-l-static
Version: 2.22.0
Release: %(echo $RELEASE)%{?dist}

Summary: ISA-L is a collection of optimized low-level functions targeting storage applications
Url: https://github.com/intel/isa-l
Group: oceanbase-devel/dependencies
License: BSD 3-Clause

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat

# disable check-buildroot
%define __arch_install_post %{nil}

%define _prefix /usr/local/oceanbase/deps/devel
%define _src isa-l-%{version}

%define debug_package %{nil}
%define __strip /bin/true
%define _buliddir %{_topdir}/BUILD
%define _tmppath %{_buliddir}/_tmp

%description
ISA-L is a collection of optimized low-level functions targeting storage applications

%build

BUILD_OPTION=''
OS_ARCH="$(uname -m)"
if [ "${OS_ARCH}x" = "ppc64lex" ]; then
    BUILD_OPTION='--build=ppc64le'
fi

rm -rf %{_tmppath}
mkdir -p %{_tmppath}
cd $OLDPWD/../
rm -rf %{_src}
tar -xf %{_src}.tar.gz
cd %{_src}
./autogen.sh
./configure ${BUILD_OPTION} --enable-static --with-pic=yes --disable-shared --prefix=%{_tmppath}
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make -j${CPU_CORES};
make install

%install

mkdir -p $RPM_BUILD_ROOT/%{_prefix}
cp -r %{_tmppath}/lib %{_tmppath}/include $RPM_BUILD_ROOT/%{_prefix}

%files 

%defattr(-,root,root)
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Fri Mar 26 2021 oceanbase
- add spec of isa-l
