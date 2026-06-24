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

# Replace STATIC_O = ao with STATIC_O = o in all files under source_dir
find ${source_dir}/icu4c/source/config -type f -exec sed -i 's/STATIC_O = ao/STATIC_O = o/g' {} \;

# compile and install
export PATH=$TOOLS_DIR/bin/:$PATH
export CC=$TOOLS_DIR/bin/gcc
export CXX=$TOOLS_DIR/bin/g++

export CFLAGS="-fPIC -fstack-protector-strong"
export CXXFLAGS="-fPIC -D_GLIBCXX_USE_CXX11_ABI=0 -fstack-protector-strong"
export LDFLAGS="-z noexecstack -z now -pie"

cd ${build_dir}
cmake .. -DICU_VERSION_DIR=icu4c -DCMAKE_INSTALL_PREFIX=${tmp_install_dir} -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DCMAKE_BUILD_TYPE=Release
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make -j${CPU_CORES} icu_all
make install

cd ${source_dir}/icu4c/source
_install_dir=$(pwd)/_install_dir
mkdir -p ${_install_dir}
mkdir build && cd build
../configure --enable-static --disable-shared --with-data-packaging=static --prefix=${_install_dir} --with-pic
make -j${CPU_CORES}
make install

# install files
cp -r ${tmp_install_dir}/lib/*.a $RPM_BUILD_ROOT/%{_prefix}/lib
cp -r ${_install_dir}/lib/libicudata.a $RPM_BUILD_ROOT/%{_prefix}/lib
cp -r ${tmp_install_dir}/include/* $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}

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
