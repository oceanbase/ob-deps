Name: devdeps-icu
Version: 69.1
Release: %(echo $RELEASE)%{?dist}
Summary: This is the repository for the International Components for Unicode
License: https://github.com/unicode-org/icu/blob/main/icu4c/LICENSE
AutoReqProv:no
%undefine _missing_build_ids_terminate_build
%define _build_id_links compat
%define _prefix /usr/local/oceanbase/deps/devel
%define _product_prefix icu
%define _src icu-release-69-1


%description
This is the repository for the International Components for Unicode

%define debug_package %{nil}
# support debuginfo package, to reduce runtime package size

# prepare your files
%install
# create dirs
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/lib
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}
cd $OLDPWD/../;
rm -rf %{_src}
tar xf %{_src}.tar.gz
cp icu-makefiles/CMakeLists.txt %{_src}
cd %{_src}
source_dir=$(pwd)
tmp_install_dir=${source_dir}/tmp_install_dir
build_dir=${source_dir}/build
rm -rf ${tmp_install_dir}
rm -rf ${build_dir}
mkdir -p ${tmp_install_dir}
mkdir -p ${build_dir}

# compile and install
export PATH=$TOOLS_DIR/bin/:$PATH
export CC=$TOOLS_DIR/bin/gcc
export CXX=$TOOLS_DIR/bin/g++
cd ${build_dir}
cmake .. -DICU_VERSION_DIR=icu4c -DCMAKE_INSTALL_PREFIX=${tmp_install_dir} -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DCMAKE_BUILD_TYPE=Release
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make -j${CPU_CORES} icu_all
make install

# install files
cp -r ${tmp_install_dir}/lib/*.a $RPM_BUILD_ROOT/%{_prefix}/lib
cp -r ${tmp_install_dir}/include/* $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}/i18n/unicode
cp ../icu4c/source/i18n/unicode/*.h $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}/i18n/unicode/


# package infomation
%files 
# set file attribute here
%defattr(-,root,root)
# need not list every file here, keep it as this
%{_prefix}
%exclude %dir %{_prefix}
%exclude %dir %{_prefix}/include
%exclude %dir %{_prefix}/lib

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Wed Nov 23 2022 xuhao.yf
- version 69.1
