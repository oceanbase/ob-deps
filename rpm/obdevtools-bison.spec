Name: obdevtools-bison
Version: 2.4.1
Release: %(echo $RELEASE)%{?dist}

Summary: Bison is a general-purpose parser generator  

Url: https://www.gnu.org/software/bison/

Group: oceanbase-devel/tools
License: GPLv3+

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat

# disable check-buildroot
%define __arch_install_post %{nil}

%define _prefix /usr/local/oceanbase/devtools/
%define _src bison-%{version}
%define debug_package %{nil}

%description
Bison is a general-purpose parser generator that converts an annotated context-free grammar into a deterministic LR or generalized LR (GLR) parser employing LALR(1) parser tables. As an experimental feature, Bison can also generate IELR(1) or canonical LR(1) parser tables. Once you are proficient with Bison, you can use it to develop a wide range of language parsers, from those used in simple desk calculators to complex programming languages.

%build

cd $OLDPWD/../
rm -rf %{_src} 
tar xf %{_src}.tar.bz2
cd %{_src}

# if you failed to build bison in an arm machine, please use following command instead.
# ./configure --build=unknown-unknown-linux --prefix=${RPM_BUILD_ROOT}/%{_prefix}

./configure --prefix=${RPM_BUILD_ROOT}/%{_prefix}
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
- add spec of bison
