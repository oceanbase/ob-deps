Name: devdeps-rocksdb
Version: %(echo $VERSION)
Release: %(echo $RELEASE)%{?dist}

Summary: A library that provides an embeddable, persistent key-value store for fast storage.

License: GPLv2 or Apache 2.0
Url: https://github.com/facebook/rocksdb
AutoReqProv:no

%undefine _missing_build_ids_terminate_build
%define _prefix /usr/local/oceanbase/deps/devel
%define _rocksdb_src rocksdb-%{version}
%define debug_package %{nil}
%define _default_version_src rocksdb-%{version}

%description
A library that provides an embeddable, persistent key-value store for fast storage.

%install
mkdir -p $RPM_BUILD_ROOT/%{_prefix}
cd $OLDPWD/../
source_dir=$(pwd)
tmp_install_dir=${source_dir}/tmp_install_dir
rm -rf ${tmp_install_dir}
mkdir -p ${tmp_install_dir}
rm -rf %{_rocksdb_src}
tar xf %{_rocksdb_src}.tar.gz
cd %{_default_version_src}
mkdir build
cd build
cmake .. -DCMAKE_INSTALL_PREFIX=${tmp_install_dir} \
         -DCMAKE_BUILD_TYPE=Release \
         -DWITH_GFLAGS=0 \
         -DPORTABLE=ON \
         -DCMAKE_CXX_STANDARD=20 \
         -DCMAKE_CXX_FLAGS='-D_GLIBCXX_USE_CXX11_ABI=0 -fPIC -Wno-array-bounds -Wno-restrict'\
         -DCMAKE_EXE_LINKER_FLAGS='-lrt' \
         -DWITH_ZSTD=ON \
         -DWITH_LZ4=ON
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make -j${CPU_CORES}
make install

# install files
cp -r ${tmp_install_dir}/* $RPM_BUILD_ROOT/%{_prefix}/

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
* Mon Feb 28 2022 oceanbase
- rocksdb-6.22.1
