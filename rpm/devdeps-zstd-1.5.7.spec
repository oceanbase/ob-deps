Name: devdeps-zstd
Version: %(echo $VERSION)
Release: %(echo $RELEASE)%{?dist}
Summary: Zstandard - fast lossless compression library and command-line tool
License: https://github.com/facebook/zstd/blob/dev/LICENSE
AutoReqProv:no

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat
# support debuginfo package, to reduce runtime package size
%define debug_package %{nil}
%define _prefix /usr/local/oceanbase/deps/devel
%define _product_prefix zstd
%define _src zstd-%{version}
%define _flag 157

%description
Zstandard - fast lossless compression library and command-line tool

%install
# create dirs
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/lib/zstd_%{_flag}
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/include/zstd_%{_flag}
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
export CFLAGS="-fPIC -fvisibility=hidden -Wno-implicit-fallthrough -DZSTDERRORLIB_VISIBILITY= -DZDICTLIB_VISIBILITY= -DZSTDLIB_VISIBILITY="
export CXXFLAGS="-fPIC -fvisibility=hidden -D_GLIBCXX_USE_CXX11_ABI=0 -Wno-implicit-fallthrough -DZSTDERRORLIB_VISIBILITY= -DZDICTLIB_VISIBILITY= -DZSTDLIB_VISIBILITY="
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

make -j${CPU_CORES} PREFIX=${tmp_install}
make install PREFIX=${tmp_install}
 
# install files
# 复制静态库 & 头文件
cp -r ${tmp_install}/lib/libzstd.a $RPM_BUILD_ROOT/%{_prefix}/lib/zstd_%{_flag}/libzstd_%{_flag}.a || true
cp -r ${tmp_install}/include/*.h $RPM_BUILD_ROOT/%{_prefix}/include/zstd_%{_flag}/ || true

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