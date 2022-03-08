Name: obdevtools-llvm
Version: 11.0.1
Release: %(echo $RELEASE)%{?dist}

Summary: The LLVM Project is a collection of modular and reusable compiler and toolchain technologies.

Group: oceanbase-devel/tools
License: Apache License Version 2.0
Url: https://github.com/llvm/llvm-project
AutoReqProv:no

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat
%global __os_install_post %{nil}
%define debug_package %{nil}
%define _prefix /usr/local/oceanbase/devtools/
%define _llvm_src llvm-%{version}.src
%define _lld_src lld-%{version}.src
%define _clang_src clang-%{version}.src
%define _buliddir %{_topdir}/BUILD
%define _relwithdebinfo_dir %{_buliddir}/product-debuginfo
%define _rel_dir %{_buliddir}/product

BuildRequires: obdevtools-cmake = 3.20.2

%description
The LLVM Project is a collection of modular and reusable compiler and toolchain technologies.

%build
# step1: build RelWithDebInfo version
rm -rf %{_relwithdebinfo_dir}
mkdir -p %{_relwithdebinfo_dir}
cd %{_topdir}/../../
rm -rf %{_llvm_src} %{_lld_src} %{_clang_src}
tar xf %{_llvm_src}.tar.xz
tar xf %{_lld_src}.tar.xz
tar xf %{_clang_src}.tar.xz

mv -f %{_lld_src} %{_llvm_src}/tools/lld
mv -f %{_clang_src} %{_llvm_src}/tools/clang

cd %{_llvm_src}
mkdir -p build-rpm
cd build-rpm

arch=`uname -p`
if [[ x"$arch" == x"x86_64" ]]; then
    echo "Build arch: x86"
    arch=x86
elif [[ x"$arch" == x"aarch64" ]]; then
    echo "Build arch: AArch64"
    arch=AArch64
else
    echo "Unknown arch"
    exit 1
fi
cmake .. -DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++" -DCMAKE_INSTALL_PREFIX=%{_relwithdebinfo_dir} -DLLVM_TARGETS_TO_BUILD=$arch -DLLVM_ENABLE_RTTI=ON -DLLVM_ENABLE_EH=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo -DLLVM_ENABLE_PROJECTS='clang;compiler-rt' -G 'Unix Makefiles';
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make -j${CPU_CORES};
make install;

# step2: build Release version
rm -rf %{_rel_dir}
mkdir -p %{_rel_dir}
cd %{_topdir}/../../
rm -rf %{_llvm_src} %{_lld_src} %{_clang_src}
tar xf %{_llvm_src}.tar.xz
tar xf %{_lld_src}.tar.xz
tar xf %{_clang_src}.tar.xz

mv -f %{_lld_src} %{_llvm_src}/tools/lld
mv -f %{_clang_src} %{_llvm_src}/tools/clang

cd %{_llvm_src}
mkdir -p build-rpm
cd build-rpm

cmake .. -DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++" -DCMAKE_INSTALL_PREFIX=%{_rel_dir} -DLLVM_TARGETS_TO_BUILD=$arch -DLLVM_ENABLE_RTTI=ON -DLLVM_ENABLE_EH=ON -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_PROJECTS='clang;compiler-rt' -G 'Unix Makefiles';
make -j${CPU_CORES};
make install;

# step3: replace asan debuginfo lib
rm -rf %{_rel_dir}/lib/clang/11.1.0/lib/linux
cp -rf %{_relwithdebinfo_dir}/lib/clang/11.1.0/lib/linux %{_rel_dir}/lib/clang/11.1.0/lib/

%install
# create dirs
# mkdir -p $RPM_BUILD_ROOT/%{_prefix}/bin
cp -r %{_rel_dir}/* $RPM_BUILD_ROOT/%{_prefix}
# install necessary tools
# cp -d %{_tmppath}/bin/clang-11 %{_tmppath}/bin/lld %{_tmppath}/bin/llvm-ar %{_tmppath}/bin/clang %{_tmppath}/bin/llvm-dlltool %{_tmppath}/bin/llvm-lib \
#    %{_tmppath}/bin/llvm-ranlib %{_tmppath}/bin/clang++ %{_tmppath}/bin/clang-cl %{_tmppath}/bin/clang-cpp %{_tmppath}/bin/ld.lld %{_tmppath}/bin/ld64.lld \
#    %{_tmppath}/bin/lld-link %{_tmppath}/bin/wasm-ld %{_tmppath}/bin/llvm-objcopy %{_tmppath}/bin/llvm-install-name-tool %{_tmppath}/bin/llvm-strip \
#    %{_tmppath}/bin/clang-format $RPM_BUILD_ROOT/%{_prefix}/bin

%files

%defattr(-,root,root)

%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Tue Mar 8 2022 oceanbase
- support asan
* Fri May 7 2021 oceanbase
- reduce rpm package size by only installing necessary files
* Thu Mar 25 2021 oceanbase
- add spec of ob-llvm
