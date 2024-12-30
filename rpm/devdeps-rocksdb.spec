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
%define _default_version_src rocksdb-6.22.1

%description
A library that provides an embeddable, persistent key-value store for fast storage.

%install
mkdir -p %{buildroot}/%{_prefix}
cd $OLDPWD/../
rm -rf %{_rocksdb_src}
tar xf %{_rocksdb_src}.tar.gz
cd %{_default_version_src}
mv ../patch/rocksdb.patch .
patch -p1 < rocksdb.patch
mkdir build
cd build
cmake .. -DCMAKE_INSTALL_PREFIX=%{buildroot}/%{_prefix} -DCMAKE_BUILD_TYPE=Release -DWITH_GFLAGS=0 -DPORTABLE=ON \
         -DCMAKE_CXX_FLAGS='-D_GLIBCXX_USE_CXX11_ABI=0 -fPIC -lrt'
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make -j${CPU_CORES}
make install

%files

%defattr(-,root,root)

%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Mon Feb 28 2022 oceanbase
- rocksdb-6.22.1
