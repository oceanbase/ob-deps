Name: devdeps-s3-cpp-sdk-with-babassl
Version: 1.11.156
Release: %(echo $RELEASE)%{?dist}
Url: https://github.com/aws/aws-sdk-cpp
Summary: This library supports the interface to operate with amazon simple storage service with C++ language.

Group: oceanbase-devel/dependencies
License: Apache 2.0

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat

# disable check-buildroot
%define __arch_install_post %{nil}

%define _prefix /usr/local/oceanbase/deps/devel
%define _src aws-sdk-cpp-%{version}

%define _buliddir %{_topdir}/BUILD
%define _tmpdir %{_buliddir}/_tmp
%define _root_dir $RPM_BUILD_ROOT%{_prefix}
%define _openssl_path /usr/local/babassl-ob
%define _curl_path /usr/local/oceanbase/deps/devel

%define debug_package %{nil}
%define __strip /bin/true

%description
This library aims to enable operation with amazon simple storage service.
It supports multi interface, like put_object、get_object, etc.

%build
rm -rf %{_root_dir}

rm -rf %{_tmpdir}
mkdir -p %{_tmpdir}

cd $OLDPWD/..;
rm -rf %{_src}
tar -zxf %{_src}.tar.gz
cd %{_src}
sh prefetch_crt_dependency.sh
rm -rf build
mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DOPENSSL_ROOT_DIR=%{_openssl_path} \
         -DCURL_INCLUDE_DIR=%{_curl_path}/include -DCURL_LIBRARY=%{_curl_path}/lib/libcurl.a \
         -DCMAKE_INSTALL_PREFIX=%{_tmpdir} -DCMAKE_PREFIX_PATH=%{_openssl_path} \
         -DBUILD_ONLY="s3" -DBUILD_SHARED_LIBS=0 -DENABLE_TESTING=0 \
         -DCUSTOM_MEMORY_MANAGEMENT=1 -DAWS_CUSTOM_MEMORY_MANAGEMENT=1
make %{_smp_mflags}
make install

%install
mkdir -p %{_root_dir}
cp -r %{_tmpdir}/lib64 %{_tmpdir}/include %{_root_dir}

%files 

%defattr(-,root,root)
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Wed Sep 9 2023 oceanbase
- add spec of aws-cpp-sdk-with-babassl for s3
