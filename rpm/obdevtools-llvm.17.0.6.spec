Name: obdevtools-llvm
Version: 17.0.6
Release: %(echo $RELEASE)%{?dist}
Url: https://github.com/llvm/llvm-project
Summary: The LLVM Project is a collection of modular and reusable compiler and toolchain technologies.
 
Group: oceanbase-devel/tools
License: Apache License Version 2.0
AutoReqProv:no

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat
%global __os_install_post %{nil}
%define debug_package %{nil}
%define _prefix /usr/local/oceanbase/devtools
%define _llvm_src llvm-%{version}.src
%define _lld_src lld-%{version}.src
%define _clang_src clang-%{version}.src
%define _compiler_rt_src compiler-rt-%{version}.src
%define _cmake_src cmake-%{version}.src
%define _third_party_src third-party-%{version}.src
%define _libunwind_src libunwind-%{version}.src
%define _buliddir %{_topdir}/BUILD
%define _rel_dir %{_buliddir}/product
 
BuildRequires: obdevtools-cmake >= 3.20.2
 
%description
The LLVM Project is a collection of modular and reusable compiler and toolchain technologies.
 
%prep
source_dir=%{_topdir}/../../
rm -rf %{_rel_dir}
mkdir -p %{_rel_dir}
cd $source_dir
rm -rf %{_llvm_src} %{_lld_src} %{_clang_src} %{_compiler_rt_src} %{_cmake_src} %{_third_party_src} %{_libunwind_src}
tar xf %{_llvm_src}.tar.xz
tar xf %{_lld_src}.tar.xz
tar xf %{_clang_src}.tar.xz
tar xf %{_compiler_rt_src}.tar.xz
tar xf %{_cmake_src}.tar.xz
tar xf %{_third_party_src}.tar.xz
tar xf %{_libunwind_src}.tar.xz
rm -rf %{_llvm_src}.tar.xz %{_lld_src}.tar.xz %{_clang_src}.tar.xz %{_compiler_rt_src}.tar.xz %{_cmake_src}.tar.xz %{_third_party_src}.tar.xz %{_libunwind_src}.tar.xz

# LLVM_ENABLE_PROJECTS requires putting module source code directory and llvm source code directory into the same directory.
# llvm_src_dir/
# ├── clang
# └── llvm
rm -rf $source_dir/llvm_src_dir
mkdir -p $source_dir/llvm_src_dir
mv -f %{_llvm_src} $source_dir/llvm_src_dir/llvm
mv -f %{_clang_src} $source_dir/llvm_src_dir/clang
mv -f %{_compiler_rt_src} $source_dir/llvm_src_dir/compiler-rt
mv -f %{_lld_src} $source_dir/llvm_src_dir/lld
mv -f %{_cmake_src} $source_dir/llvm_src_dir/cmake
mv -f %{_third_party_src} $source_dir/llvm_src_dir/third-party
mv -f %{_libunwind_src} $source_dir/llvm_src_dir/libunwind
rm -rf %{_llvm_src} %{_lld_src} %{_clang_src} %{_compiler_rt_src} %{_cmake_src} %{_third_party_src} %{_libunwind_src}

%build
# build Release or RelWithDebInfo version
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
source_dir=%{_topdir}/../../
export TMPDIR=$source_dir/tmp
mkdir -p $TMPDIR
cd $source_dir/llvm_src_dir
mkdir -p build-rpm
cd build-rpm

cmake ../llvm  \
    -DCMAKE_CXX_FLAGS="-D_GLIBCXX_USE_CXX11_ABI=0" \
    -DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++" \
    -DCMAKE_AR=${AR} \
    -DCMAKE_RANLIB=${RANLIB} \
    -DCMAKE_INSTALL_PREFIX=%{_rel_dir} \
    -DLLVM_TARGETS_TO_BUILD="AArch64;X86;" \
    -DLLVM_ENABLE_RTTI=ON \
    -DLLVM_ENABLE_EH=ON \
    -DLLVM_ENABLE_DUMP=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_PROJECTS='clang;compiler-rt;lld' \
    -G 'Unix Makefiles';
make -j${CPU_CORES};
make install;

%install
# create dirs
mkdir -p $RPM_BUILD_ROOT/%{_prefix}
cp -r %{_rel_dir}/* $RPM_BUILD_ROOT/%{_prefix}
cd $RPM_BUILD_ROOT/%{_prefix}/bin
ln -sf clang-17 clang++-17

%files
%defattr(-,root,root)
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig
 
%changelog
* Thu Nov 21 2024 huaixin.lmy
- add spec of llvm-17.0.6
