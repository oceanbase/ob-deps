Name: devdeps-s2geometry
Version: 0.10.0
Release: %(echo $RELEASE)%{?dist}
Summary: This is a package for manipulating geometric shapes.
Group: alibaba/application
License: Apache 2.0
AutoReqProv:no
%undefine _missing_build_ids_terminate_build
%define _build_id_links compat
%define _prefix /usr/local/oceanbase/deps/devel
%define _product_prefix s2
%define _src s2geometry-%{version}


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
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/lib64
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

# compile and install
export CFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0 -fPIC -pie -fstack-protector-strong"
export CXXFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0 -fPIC -pie -fstack-protector-strong"
export LDFLAGS="-pie -z noexecstack -z now"

cd ${build_dir}
OPENSSL_ROOT_DIR=$DEP_DIR
cmake .. -DCMAKE_INSTALL_PREFIX=${tmp_install_dir} -DCMAKE_PREFIX_PATH=$DEP_DIR -DCMAKE_CXX_STANDARD=14 -DCMAKE_CXX_STANDARD_REQUIRED=ON -DBUILD_SHARED_LIBS=OFF -DBUILD_EXAMPLES=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DCMAKE_BUILD_TYPE=Release
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make -j${CPU_CORES}
make install

# install files
cp -r ${tmp_install_dir}/include/s2/* $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}
cp -r ${tmp_install_dir}/lib64/* $RPM_BUILD_ROOT/%{_prefix}/lib64/

# package infomation
%files 
# set file attribute here
%defattr(-,root,root)
# need not list every file here, keep it as this
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Thu Dec 19 2024 huaixin.lmy
- version 0.10.0
* Mon Mar 09 2022 xuhao.yf
- version 0.9.0
