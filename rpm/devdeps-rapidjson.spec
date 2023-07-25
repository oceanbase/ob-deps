Name: devdeps-rapidjson
Version: 1.1.0
Release: %(echo $RELEASE)%{?dist}

Summary: RapidJSON is a JSON parser and generator for C++.

License: MIT and BSD
Url: https://github.com/Tencent/rapidjson
AutoReqProv:no

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat
%define _prefix /usr/local/oceanbase/deps/devel
%define _src rapidjson-%{version}
%define debug_package %{nil}

%description
RapidJSON is a JSON parser and generator for C++.

%install
cd $OLDPWD/..
rm -rf %{_src}
tar -zxf %{_src}.tar.gz
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/include
\cp -r %{_src}/include/rapidjson $RPM_BUILD_ROOT/%{_prefix}/include

%files
%defattr(-,root,root)
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Fri Oct 15 2021 oceanbase
- devdeps-rapidjson-1.1.0