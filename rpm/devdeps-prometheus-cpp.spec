Name: devdeps-prometheus-cpp
Version: 0.8.0
Release: %(echo $RELEASE)%{?dist}
Url: https://github.com/jupp0r/prometheus-cpp
Summary: This library implements the Prometheus Data Model to enable Metrics-Driven Development for C++ services.

Group: oceanbase-devel/dependencies
License: MIT

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat

# disable check-buildroot
%define __arch_install_post %{nil}

%define _prefix /usr/local/oceanbase/deps/devel
%define _src prometheus-cpp-%{version}

%define debug_package %{nil}
%define __strip /bin/true

%description
This library aims to enable Metrics-Driven Development for C++ services. 
It implements the Prometheus Data Model, a powerful abstraction on which to collect and expose metrics.

%install

mkdir -p $RPM_BUILD_ROOT/%{_prefix}
cd $OLDPWD/../;
rm -rf %{_src}
tar xvf %{_src}.tar.gz
cd %{_src}
mkdir _build
cd _build
# Please use gcc5.2 or higher version
export CFLAGS=-D_GLIBCXX_USE_CXX11_ABI=0
export CXXFLAGS=-D_GLIBCXX_USE_CXX11_ABI=0
cmake .. -DCMAKE_INSTALL_PREFIX=%{_prefix} -DBUILD_SHARED_LIBS=OFF
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make -j${CPU_CORES};
make DESTDIR=$RPM_BUILD_ROOT install

%files 

%defattr(-,root,root)
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Mon Apr 12 2021 oceanbase
- add spec of prometheus-cpp