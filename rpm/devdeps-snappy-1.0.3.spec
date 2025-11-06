Name: devdeps-snappy
Version: %(echo $VERSION)
Release: %(echo $RELEASE)%{?dist}
Summary: A fast compressor/decompressor. It does not aim for maximum compression, but rather for high speed and reasonable compression.
License: https://github.com/google/snappy?tab=License-1-ov-file
AutoReqProv:no

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat
# support debuginfo package, to reduce runtime package size
%define debug_package %{nil}
%define _prefix /usr/local/oceanbase/deps/devel
%define _product_prefix snappy
%define _src snappy-%{version}

%description
A fast compressor/decompressor. It does not aim for maximum compression, but rather for high speed and reasonable compression.

%install
# create dirs
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/lib/snappy
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/include/snappy
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
ROOT_DIR=$OLDPWD/..

# compile and install
cd $ROOT_DIR
source_dir=$(pwd)
TMP_INSTALL=${source_dir}/tmp_install
rm -rf ${TMP_INSTALL}
mkdir -p ${TMP_INSTALL}
rm -rf %{_src}
mkdir -p %{_src}
tar -xf %{_src}.tar.gz -C %{_src} --strip-components=0
cd %{_src}

sed -i '16iAM_PROG_AR' ./configure.ac
./autogen.sh
./configure \
    --prefix=$TMP_INSTALL \
    --enable-static \
    --disable-shared \
    --disable-dependency-tracking \
    CXXFLAGS="-fPIC -fvisibility=hidden" \
    CFLAGS="-fPIC -fvisibility=hidden"
make -j${CPU_CORES}
make install

# 符号本地化（避免符号冲突）
find $TMP_INSTALL/lib -name "*.a" -exec objcopy --localize-hidden {} \;

# 复制静态库 & 头文件
cp -r ${source_dir}/%{_src}/*.h $TMP_INSTALL/include/
cp -r $TMP_INSTALL/include/* $RPM_BUILD_ROOT/%{_prefix}/include/snappy
cp -r $TMP_INSTALL/lib/* $RPM_BUILD_ROOT/%{_prefix}/lib/snappy

# package infomation
%files 
# set file attribute here
%defattr(-,root,root)
# need not list every file here, keep it as this
%{_prefix}
%exclude %dir %{_prefix}
%exclude %dir %{_prefix}/include
%exclude %dir %{_prefix}/lib64
 
%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig
 
%changelog
* Tue Oct 28 2025 huaixin.lmy
- version init
