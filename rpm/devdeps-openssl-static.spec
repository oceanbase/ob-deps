Name: devdeps-openssl-static
Version: 1.1.1u
Release: %(echo $RELEASE)%{?dist}

Summary: OpenSSL is a robust, commercial-grade, and full-featured toolkit for the Transport Layer Security (TLS) and Secure Sockets Layer (SSL) protocols.
Url: https://www.openssl.org/
Group: oceanbase-devel/dependencies
License: Apache 2.0 (https://github.com/openssl/openssl/blob/master/LICENSE.txt)
AutoReqProv:no

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat
# disable check-buildroot
%define __arch_install_post %{nil}
# support debuginfo package, to reduce runtime package size
%define debug_package %{nil}

%define _prefix /usr/local/oceanbase/deps/devel
%define _src openssl-%{version}

%description
OpenSSL is a robust, commercial-grade, and full-featured toolkit for the Transport Layer Security (TLS) and Secure Sockets Layer (SSL) protocols. 
It is also a general-purpose cryptography library. For more information about the team and community around the project, or to start making your own contributions, 
start with the community page. To get the latest news, download the source, and so on, please see the sidebar or the buttons at the top of every page.

%build

# incompat with openssl config. unset it here
unset RELEASE
export CFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0 -fPIC -pie -fstack-protector-strong"
export CXXFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0 -fPIC -pie -fstack-protector-strong"
export LDFLAGS="-pie -z noexecstack -z now"

cd $OLDPWD/../
rm -rf %{_src}
tar -xf %{_src}.tar.gz
cd %{_src}
./config --prefix=%{_prefix} -fPIC no-shared --openssldir=%{_prefix}
make depend
make all
make install_sw

%install

mkdir -p $RPM_BUILD_ROOT/%{_prefix}
cp -r %{_prefix}/lib %{_prefix}/include $RPM_BUILD_ROOT/%{_prefix}

%files 

%defattr(-,root,root)
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Thu Mar 20 2025 huaixin.lmy
- upgrade version to 1.1.1u
* Fri Mar 26 2021 oceanbase
- add spec of cmake
