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
mkdir -p %{buildroot}/%{_prefix}
cd $OLDPWD/../
rm -rf %{_rocksdb_src}
tar xf %{_rocksdb_src}.tar.gz
cd %{_default_version_src}

OS_ARCH="$(uname -m)"
EXTRA_FLAGS=""
if [ x"${OS_ARCH}" == x"loongarch64" ]; then
    EXTRA_FLAGS="-mcmodel=large"
    sed -i '135a\
#elif defined(__loongarch__) // 添加龙芯架构支持\
  uint64_t result;\
  // 使用rdtime.d指令读取时间计数器\
  __asm__ __volatile__("rdtime.d %0, $zero" : "=r"(result));\
  return result;' ./utilities/transactions/lock/range/range_tree/lib/portability/toku_time.h

fi

cp ../patch/rocksdb.patch .
patch -p1 < rocksdb.patch
mkdir build
cd build
cmake .. -DCMAKE_INSTALL_PREFIX=%{buildroot}/%{_prefix} -DCMAKE_BUILD_TYPE=Release -DWITH_GFLAGS=0 -DPORTABLE=ON \
         -DCMAKE_CXX_FLAGS="-D_GLIBCXX_USE_CXX11_ABI=0 -fPIC -lrt ${EXTRA_FLAGS}"
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
