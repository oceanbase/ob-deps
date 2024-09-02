Name: devdeps-hyperscan
Version: 5.4.2
Release: %(echo $RELEASE)%{?dist}
Summary: This is the repository for the Intel Hyperscan
License: https://github.com/intel/hyperscan/blob/master/LICENSE
AutoReqProv:no
%undefine _missing_build_ids_terminate_build
%define _build_id_links compat
%define _prefix /usr/local/oceanbase/deps/devel
%define _product_prefix hyperscan
%define _src hyperscan-5.4.2
%define _boost boost_1_84_0
%define _ragel ragel-6.10


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

export PATH=$TOOLS_DIR/bin/:$PATH
export CC=$TOOLS_DIR/bin/gcc
export CXX=$TOOLS_DIR/bin/g++
export LD_LIBRARY_PATH=$TOOLS_DIR/lib64/:$DEP_DIR/lib/
CPU_CORES=`grep -c ^processor /proc/cpuinfo`

# prepare boost
rm -rf %{_boost}
tar xf %{_boost}.tar.gz
boost_dir=$(pwd)/%{_boost}
boost_install_dir=${boost_dir}/install
rm -rf ${boost_install_dir}
mkdir -p ${boost_install_dir}
cd ${boost_dir}
./bootstrap.sh --prefix=${boost_install_dir}
./b2 install

# prepare ragel
cd ../
rm -rf %{_ragel}
tar xf %{_ragel}.tar.gz
ragel_dir=$(pwd)/%{_ragel}
ragel_install_dir=${ragel_dir}/install
rm -rf ${ragel_install_dir}
mkdir -p ${ragel_install_dir}
cd ${ragel_dir}
./configure --prefix=${ragel_install_dir}
make -j${CPU_CORES}
make install
export PATH=${ragel_install_dir}/bin/:$PATH

cd ../
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
cd ${build_dir}
cmake .. -DBOOST_ROOT=${boost_install_dir}/include -DCMAKE_POSITION_INDEPENDENT_CODE=on -DBUILD_STATIC_AND_SHARED=on -DCMAKE_INSTALL_PREFIX=${tmp_install_dir} -DCMAKE_C_FLAGS="-fno-reorder-blocks-and-partition" -DCMAKE_CXX_FLAGS="-fno-reorder-blocks-and-partition"
make -j${CPU_CORES}
make install

# install files
cp -r ${tmp_install_dir}/lib64/*.a $RPM_BUILD_ROOT/%{_prefix}/lib
cp -r ${tmp_install_dir}/lib64/*.so.5.4.2 $RPM_BUILD_ROOT/%{_prefix}/lib
cp $RPM_BUILD_ROOT/%{_prefix}/lib/libhs.so.5.4.2 $RPM_BUILD_ROOT/%{_prefix}/lib/libhs.so.5
cp $RPM_BUILD_ROOT/%{_prefix}/lib/libhs.so.5.4.2 $RPM_BUILD_ROOT/%{_prefix}/lib/libhs.so
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
* Wed Nov 04 2024 zongmei.zzm
- version v5.4.2
