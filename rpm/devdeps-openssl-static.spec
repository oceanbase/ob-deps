Name: devdeps-openssl-static
Version: 1.0.1e
Release: %(echo $RELEASE)%{?dist}

Summary: OpenSSL is a robust, commercial-grade, and full-featured toolkit for the Transport Layer Security (TLS) and Secure Sockets Layer (SSL) protocols.
Url: https://www.openssl.org/
Group: oceanbase-devel/dependencies
License: OpenSSL
AutoReqProv:no

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat

# disable check-buildroot
%define __arch_install_post %{nil}

%define _prefix /usr/local/oceanbase/deps/devel
%define _src openssl-%{version}

%define debug_package %{nil}
%define __strip /bin/true

%define _buliddir %{_topdir}/BUILD
%define _tmppath %{_buliddir}/_tmp

%description
OpenSSL is a robust, commercial-grade, and full-featured toolkit for the Transport Layer Security (TLS) and Secure Sockets Layer (SSL) protocols. 
It is also a general-purpose cryptography library. For more information about the team and community around the project, or to start making your own contributions, 
start with the community page. To get the latest news, download the source, and so on, please see the sidebar or the buttons at the top of every page.

%build

# incompat with openssl config. unset it here
unset RELEASE
rm -rf %{_tmppath}
mkdir -p %{_tmppath}
cd $OLDPWD/../
rm -rf %{_src}
tar -xf %{_src}.tar.gz
cd %{_src}
make dclean
./config -fPIC no-krb5 no-shared --openssldir=%{_tmppath}
make depend
make all
make install_sw

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
- add spec of cmake
