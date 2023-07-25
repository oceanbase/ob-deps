Name: devdeps-s2geometry
Version: 0.9.0
Release: %(echo $RELEASE)%{?dist}
Summary: This is a package for manipulating geometric shapes.
Group: alibaba/application
License: Apache2.0
AutoReqProv:no
%undefine _missing_build_ids_terminate_build
%define _build_id_links compat
%define _prefix /usr/local/oceanbase/deps/devel
%define _product_prefix s2
%define _src s2geometry-0.9.0


%description
This is a package for manipulating geometric shapes. 
Unlike many geometry libraries, S2 is primarily designed to work with spherical geometry, i.e., shapes drawn on a sphere rather than on a planar 2D map. 
This makes it especially suitable for working with geographic data.

%define debug_package %{nil}
# support debuginfo package, to reduce runtime package size

# prepare your files
%install
# create dirs
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/lib
cd $OLDPWD/../;
rm -rf %{_src}
tar xf %{_src}.tar.gz
cd %{_src}
source_dir=$(pwd)
tmp_install_dir=${source_dir}/tmp_install_dir
build_dir=${source_dir}/build
rm -rf ${tmp_install_dir}
rm -rf ${build_dir}
mkdir -p ${tmp_install_dir}
mkdir -p ${build_dir}

# disable compiling python interface
sed -i '/find_package(SWIG)/d' ${source_dir}/CMakeLists.txt
sed -i '/find_package(PythonInterp)/d' ${source_dir}/CMakeLists.txt
sed -i '/find_package(PythonLibs)/d' ${source_dir}/CMakeLists.txt

# disable compiling test file
sed -i '/add_library(s2testing STATIC/d' ${source_dir}/CMakeLists.txt
sed -i '/s2builderutil_testing.cc/d' ${source_dir}/CMakeLists.txt
sed -i '/s2shapeutil_testing.cc/d' ${source_dir}/CMakeLists.txt
sed -i '/s2testing.cc/d' ${source_dir}/CMakeLists.txt
sed -i 's/install(TARGETS s2 s2testing DESTINATION lib)/install(TARGETS s2 DESTINATION lib)/' ${source_dir}/CMakeLists.txt

# fix uint64 error in aarch64: https://github.com/google/s2geometry/pull/166
cp ${source_dir}/../s2geometry-0.9.0-uint64.patch ${source_dir}
patch -p0 < s2geometry-0.9.0-uint64.patch

# compile and install
export PATH=$TOOLS_DIR/bin/:$PATH
export CC=$TOOLS_DIR/bin/gcc
export CXX=$TOOLS_DIR/bin/g++
cd ${build_dir}
OPENSSL_ROOT_DIR=$DEP_DIR cmake .. -DCMAKE_INSTALL_PREFIX=${tmp_install_dir} -DBUILD_SHARED_LIBS=OFF -DBUILD_EXAMPLES=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DCMAKE_BUILD_TYPE=Release
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make -j${CPU_CORES}
make install

# install files
cp -r ${tmp_install_dir}/include/s2/* $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}
cp -r ${tmp_install_dir}/lib/* $RPM_BUILD_ROOT/%{_prefix}/lib

# package infomation
%files 
# set file attribute here
%defattr(-,root,root)
# need not list every file here, keep it as this
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Mon Mar 09 2022 xuhao.yf
- version 0.9.0