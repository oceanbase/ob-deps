Name: obdevtools-llvm
Version: 13.0.1
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
%define _buliddir %{_topdir}/BUILD
%define _rel_dir %{_buliddir}/product

BuildRequires: obdevtools-cmake >= 3.20.2

%description
The LLVM Project is a collection of modular and reusable compiler and toolchain technologies.

%build
source_dir=%{_topdir}/../../
cd $source_dir
tar -xf $source_dir/llvm-project_$VERSION-5.src.tar.gz
cd llvm-project-$VERSION
mkdir -p build-rpm
cd build-rpm

cmake \
  -DCMAKE_CXX_FLAGS="-fPIC -D_GLIBCXX_USE_CXX11_ABI=0 -mcmodel=large" \
  -DCMAKE_CXX_LINK_FLAGS="-mcmodel=large" \
  -DCMAKE_SHARED_LINKER_FLAGS="-mcmodel=large" \
  -DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++ -mcmodel=large" \
  -DCMAKE_C_COMPILER=${CC} \
  -DCMAKE_CXX_COMPILER=${CXX}\
  -DGCC_INSTALL_PREFIX=/usr \
  -DCMAKE_VERBOSE_MAKEFILE=ON \
  -DCMAKE_AR=${AR} \
  -DCMAKE_RANLIB=${RANLIB} \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_INSTALL_PREFIX=%{_rel_dir} \
  \
     ../llvm \
  \
  -DLLVM_TARGETS_TO_BUILD="LoongArch" \
  -DLLVM_INSTALL_UTILS=ON \
  -DLLVM_ENABLE_OCAMLDOC=OFF \
  -DLLVM_ENABLE_BINDINGS=OFF \
  -DLLVM_BUILD_LLVM_DYLIB=ON \
  -DLLVM_LINK_LLVM_DYLIB=ON \
  -DLLVM_ENABLE_FFI=ON \
  -DLLVM_ENABLE_RTTI=ON \
  -DLLVM_ENABLE_EH=ON \
  -DLLVM_ENABLE_DUMP=ON \
  -DLLVM_ENABLE_ASSERTIONS=OFF \
  -DLLVM_ENABLE_PROJECTS="clang;lld;compiler-rt" \
  -DLLVM_APPEND_VC_REV=OFF

make -j$(nproc)
make install


%install
# create dirs
mkdir -p $RPM_BUILD_ROOT/%{_prefix}
cp -r %{_rel_dir}/* $RPM_BUILD_ROOT/%{_prefix}

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
