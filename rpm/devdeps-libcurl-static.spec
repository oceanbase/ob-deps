Name: devdeps-libcurl-static
Version: 8.12.1
Release: %(echo $RELEASE)%{?dist}
Url: https://curl.se/
Summary: curl is a tool for transferring data with URL syntax, supporting HTTP, HTTPS, FILE

Group: oceanbase-devel/dependencies
License: MIT

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat
# disable check-buildroot
%define __arch_install_post %{nil}
%define debug_package %{nil}
%define __strip /bin/true

%define _prefix /usr/local/oceanbase/deps/devel
%define _src curl-%{version}
%define _buliddir %{_topdir}/BUILD
%define _tmppath %{_buliddir}/_tmp

%description
curl is a tool for transferring data with URL syntax, supporting HTTP, HTTPS, FILE. curl supports SSL certificates

%install
export CFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0 -fPIC -pie -fstack-protector-strong"
export CXXFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0 -fPIC -pie -fstack-protector-strong"
export LDFLAGS="-pie -z noexecstack -z now"
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
mkdir -p $RPM_BUILD_ROOT/%{_prefix}
rm -rf %{_tmppath}
mkdir -p %{_tmppath}

cd $OLDPWD/../
rm -rf %{_src}
tar -xf %{_src}.tar.gz
cd %{_src}

BUILD_OPTION=''
OS_ARCH="$(uname -m)"
if [ "${OS_ARCH}x" = "sw_64x" ]; then
    BUILD_OPTION='--build=sw_64-unknown-linux-gnu'
elif [ "${OS_ARCH}x" = "aarch64x" ]; then
    BUILD_OPTION='--build=aarch64-unknown-linux-gnu'
elif [ "${OS_ARCH}x" = "ppc64lex" ]; then
    BUILD_OPTION='--build=ppc64le'
fi

./configure --prefix=%{_tmppath} PKG_CONFIG="pkg-config SSL_LIBS=-l:libssl.a -l:libcrypto.a" --without-libssh2 --without-nss --disable-ftp \
            --disable-ldap --disable-ldaps --without-cyassl --without-polarssl --without-winssl --without-gnutls --with-ssl=${DEP_DIR} \
            --disable-cookies --disable-rtsp --without-zlib --disable-pop3 --without-libpsl --disable-smtp --disable-imap --disable-telnet \
            --disable-tftp --disable-verbose --disable-gopher --enable-shared=no --with-pic=yes ${BUILD_OPTION}
make curl_LDFLAGS=-all-static
make -j${CPU_CORES};
make curl_LDFLAGS=-all-static install

cp -r %{_tmppath}/lib %{_tmppath}/include $RPM_BUILD_ROOT/%{_prefix}

%files 

%defattr(-,root,root)
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Thu Mar 20 2025 huaixin.lmy
- upgrade curl version to 8.12.1
* Fri Mar 26 2021 oceanbase
- add spec of libcurl
