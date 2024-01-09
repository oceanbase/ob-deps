Name: devdeps-cos-c-sdk
Version: 5.0.16
Release: %(echo $RELEASE)%{?dist}
Url: https://github.com/tencentyun/cos-c-sdk-v5/
Summary: This library supports the interface to operate with tencent cloud object storage service with C language.

Group: oceanbase-devel/dependencies
License: MIT

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat

# disable check-buildroot
%define __arch_install_post %{nil}

%define _prefix /usr/local/oceanbase/deps/devel
%define _src cos-c-sdk-%{version}

%define _buliddir %{_topdir}/BUILD
%define _tmpdir %{_buliddir}/_tmp
%define _tmp_product %{_tmpdir}/_product
%define _tmp_third %{_tmpdir}/_third
%define _apr_path /usr/local/apr/

%define debug_package %{nil}
%define __strip /bin/true

%description
This library aims to enable operation with tencent cloud object storage service.
It supports multi interface, like put_object、get_object, etc.

%install
rm -rf $RPM_BUILD_ROOT/%{_prefix}
mkdir -p $RPM_BUILD_ROOT/%{_prefix}

rm -rf %{_tmpdir}
mkdir -p %{_tmpdir}
mkdir -p %{_tmp_third}

#step 1: install libcurl
cd $OLDPWD/../;
cd curl-8.1.2
./configure --prefix=%{_tmp_third} --without-ssl
make

#step 2: install expat
cd ../expat-2.5.0
./configure --prefix=%{_tmp_third}
make

#step 3: install apr
cd ../apr-1.7.4
./configure --prefix=%{_apr_path}
make
make install

#step 4: install apr-util
cd ../apr-util-1.6.3
./configure --with-apr=%{_apr_path}/bin/apr-1-config --prefix=%{_apr_path}
make
make install

#step 5: install minixml
cd ../mxml-3.3
CFLAG="-O2" \
./configure --prefix=/usr/local
make
make install

#step 6: install cos-c-sdk
cd ../cos-c-sdk-5.0.16
mkdir -p _build_rpm
cd _build_rpm
cmake ..
make
make install DESTDIR=%{_tmp_product}

cp -r %{_tmp_product}/usr/local/* $RPM_BUILD_ROOT/%{_prefix}

%files 

%defattr(-,root,root)
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Mon Jul 3 2023 oceanbase
- add spec of cos-c-sdk
