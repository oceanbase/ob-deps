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
%define debug_package %{nil}
%define _prefix /usr/local/oceanbase/devtools/
%define _llvm_src llvm-%{version}.src
%define _lld_src lld-%{version}.src
%define _clang_src clang-%{version}.src
%define _buliddir %{_topdir}/BUILD
%define _tmppath %{_buliddir}/_tmp

BuildRequires: obdevtools-cmake = 3.20.2

%description
The LLVM Project is a collection of modular and reusable compiler and toolchain technologies.

%build

rm -rf %{_tmppath}
mkdir -p %{_tmppath}
cd $OLDPWD/../
rm -rf %{_llvm_src} %{_lld_src} %{_clang_src}
tar xf %{_llvm_src}.tar.xz
tar xf %{_lld_src}.tar.xz
tar xf %{_clang_src}.tar.xz

mv -f %{_lld_src} %{_llvm_src}/tools/lld
mv -f %{_clang_src} %{_llvm_src}/tools/clang

cd %{_llvm_src}
mkdir -p build-rpm
cd build-rpm

export PATH=/usr/local/oceanbase/devtools/bin:$PATH
cmake .. -DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++" -DCMAKE_INSTALL_PREFIX=%{_tmppath} -DLLVM_TARGETS_TO_BUILD='AArch64' -DLLVM_ENABLE_RTTI=ON -DLLVM_ENABLE_EH=ON -DCMAKE_BUILD_TYPE=Release -G 'Unix Makefiles';
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
make -j${CPU_CORES};;
make install;
# drop unnecessary .a files
rm -rf %{_tmppath}/lib/*.a

%install

# create dirs
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/bin
cp -r %{_tmppath}/lib $RPM_BUILD_ROOT/%{_prefix}
# install necessary tools
cp -d %{_tmppath}/bin/clang-11 %{_tmppath}/bin/lld %{_tmppath}/bin/llvm-ar %{_tmppath}/bin/clang %{_tmppath}/bin/llvm-dlltool %{_tmppath}/bin/llvm-lib \
   %{_tmppath}/bin/llvm-ranlib %{_tmppath}/bin/clang++ %{_tmppath}/bin/clang-cl %{_tmppath}/bin/clang-cpp %{_tmppath}/bin/ld.lld %{_tmppath}/bin/ld64.lld \
   %{_tmppath}/bin/lld-link %{_tmppath}/bin/wasm-ld %{_tmppath}/bin/llvm-objcopy %{_tmppath}/bin/llvm-install-name-tool %{_tmppath}/bin/llvm-strip \
   %{_tmppath}/bin/clang-format $RPM_BUILD_ROOT/%{_prefix}/bin

%files

%defattr(-,root,root)

%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Fri May 7 2021 oceanbase
- reduce rpm package size by only installing necessary files
* Thu Mar 25 2021 oceanbase
- add spec of ob-llvm
