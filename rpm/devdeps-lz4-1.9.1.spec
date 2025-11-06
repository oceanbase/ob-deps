Name: devdeps-lz4
Version: %(echo $VERSION)
Release: %(echo $RELEASE)%{?dist}
Summary: LZ4 is a very fast lossless compression algorithm, providing compression speed at hundreds of MB/s per core.
License: https://github.com/lz4/lz4?tab=License-1-ov-file
AutoReqProv:no

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat
# support debuginfo package, to reduce runtime package size
%define debug_package %{nil}
%define _prefix /usr/local/oceanbase/deps/devel
%define _product_prefix lz4
%define _src lz4-%{version}

%description
LZ4 is a very fast lossless compression algorithm, providing compression speed at hundreds of MB/s per core.

%install
# create dirs
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/lib/lz4
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/include/lz4_191
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
export CFLAGS="-fPIC -fvisibility=hidden -DLZ4LIB_VISIBILITY="
export CXXFLAGS="-fPIC -fvisibility=hidden -D_GLIBCXX_USE_CXX11_ABI=0 -DLZ4LIB_VISIBILITY="
ROOT_DIR=$OLDPWD/..

# compile and install
cd $ROOT_DIR
source_dir=$(pwd)
tmp_install=${source_dir}/tmp_install
rm -rf ${tmp_install}
mkdir -p ${tmp_install}
rm -rf %{_src}
mkdir -p %{_src}
tar -xf %{_src}.tar.gz -C %{_src} --strip-components=1
cd %{_src}

make -j${CPU_CORES} PREFIX=${tmp_install} lib
make install PREFIX=${tmp_install}
 
# install files
# 复制静态库 & 头文件
cp -r ${tmp_install}/lib/liblz4.a $RPM_BUILD_ROOT/%{_prefix}/lib/lz4/lz4_191.a || true
cp -r ${tmp_install}/include/lz4.h $RPM_BUILD_ROOT/%{_prefix}/include/lz4_191/ || true
cp -r ${tmp_install}/include/lz4hc.h $RPM_BUILD_ROOT/%{_prefix}/include/lz4_191/ || true
# 符号本地化（防止符号冲突）
echo "Localizing symbols..."
objcopy --localize-hidden "$RPM_BUILD_ROOT/%{_prefix}/lib/lz4/lz4_191.a"

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
