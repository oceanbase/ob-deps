Name: babassl-ob
Version: 8.3.7
Release: %(echo $RELEASE)%{?dist}
# if you want use the parameter of rpm_create on build time,
# uncomment below
Summary: BabaSSL for oceanbase
Group: alibaba/application
License: Boost Software License
Url: http://tongsuo.com
%undefine _missing_build_ids_terminate_build
%define _build_id_links compat
# disable check-buildroot
%define __arch_install_post %{nil}
%define _prefix /usr/local/babassl-ob
%define _src BabaSSL_%{version}

%description
BabaSSL is a modern cryptographic and secure protocol library developed by the amazing people in Alibaba Digital Economy.

%define debug_package %{nil}
# support debuginfo package, to reduce runtime package size

# prepare your files
%install
# OLDPWD is the dir of rpm_create running
# _prefix is an inner var of rpmbuild,
# can set by rpm_create, default is "/home/a"
# _lib is an inner var, maybe "lib" or "lib64" depend on OS
mkdir -p $RPM_BUILD_ROOT/%{_prefix}
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
ROOT_DIR=$OLDPWD/..

cd $ROOT_DIR
rm -rf %{_src}
mkdir -p %{_src}
cd %{_src}
cp -r ../BabaSSL/* ./

OS_ARCH="$(uname -m)"
if [ x"${OS_ARCH}" == x"loongarch64" ]; then
    export CFLAGS="${CFLAGS} -mcmodel=large"
    export CXXFLAGS="${CXXFLAGS} -mcmodel=large"
    export LDFLAGS="${LDFLAGS} -mcmodel=large"
    if [ ! -f ../loongarch/10-main.conf ]; then
        echo "Missing loongarch/10-main.conf for loongarch64 BabaSSL build"
        exit 1
    fi
    cp ../loongarch/10-main.conf Configurations/
fi

./Configure -fPIC linux-${OS_ARCH} \
            enable-external-tests enable-ssl3 \
            enable-ssl3-method enable-ntls enable-sm2 \
            --prefix=${RPM_BUILD_ROOT}/%{_prefix}
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make -j${CPU_CORES};
make install

%files
%defattr(-,root,root)
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Thu Mar 10 2022 xuhao.yf
- upgrade to 8.3.7
