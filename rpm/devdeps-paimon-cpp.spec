Name: %(echo devdeps-paimon-cpp$ABI_FLAG)
Version: %(echo $VERSION)
Release: %(echo $RELEASE)%{?dist}
Summary: Alibaba Paimon C++ client library and dependencies

Group: oceanbase-devel/dependencies
License: Apache-2.0
URL: https://github.com/alibaba/paimon-cpp

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat
%define __arch_install_post %{nil}
%define debug_package %{nil}
%define _prefix /usr/local/oceanbase/deps/devel
%define _src paimon-cpp-%{version}

%description
Paimon C++ library built for OceanBase devdeps (Ninja, old C++11 ABI, Jindo disabled).

%install
mkdir -p $RPM_BUILD_ROOT/%{_prefix}

# _FORTIFY_SOURCE (often from rpmbuild) requires -O; third_party TBB etc. inherit these flags
export CFLAGS="-O2 -fPIC -z noexecstack -z now -pie -fstack-protector-strong"
export CXXFLAGS="-O2 -fPIC -z noexecstack -z now -pie -fstack-protector-strong"
export CPPFLAGS="${ABI_CXXFLAGS}"
CPU_CORES=8
ROOT_DIR=$OLDPWD/..

cd $ROOT_DIR
rm -rf %{_src}
mkdir -p %{_src}
tar zxf %{_src}.tar.gz --strip-components=1 -C %{_src}
cd %{_src}

# Drop Jindo SDK download (Aliyun-only tarball); CMake keeps PAIMON_ENABLE_JINDO=OFF
grep -v 'PAIMON_JINDOSDK' third_party/versions.txt > third_party/versions.txt.tmp
mv -f third_party/versions.txt.tmp third_party/versions.txt

# Offline: place third_party.tar.gz next to paimon-cpp-*.tar.gz ($ROOT_DIR); else download
if [ -f "$ROOT_DIR/third_party.tar.gz" ]; then
  tar -xf "$ROOT_DIR/third_party.tar.gz" --strip-components=1 -C third_party/
else
  bash third_party/download_dependencies.sh
fi

rm -rf build && mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=${RPM_BUILD_ROOT}/%{_prefix} \
         -DCMAKE_BUILD_TYPE=RelWithDebInfo \
         -DCMAKE_SHARED_LINKER_FLAGS="-static-libstdc++ -static-libgcc -Wl,-rpath,\$ORIGIN" \
         -DPAIMON_USE_CXX11_ABI=OFF \
         -DPAIMON_BUILD_TESTS=OFF \
         -DPAIMON_ENABLE_JINDO=OFF \
         -DPAIMON_BUILD_STATIC=ON \
         -DPAIMON_BUILD_SHARED=ON
make -j${CPU_CORES}

# ---- 单体 lib_ob_paimon.so：把 paimon 全部组件和第三方静态库重链接成一个 .so ----
# 动机：
# 1) 多 .so 各自带一份（隐藏可见性的）静态 libstdc++ 时，跨 .so 传 std::string /
#    抛异常会踩 empty-rep 地址比较、typeinfo 地址比较不一致的雷；单 DSO 内只有
#    一份 libstdc++，问题从根上消失。
# 2) 不再依赖目标机的 libstdc++.so.6，修复老系统（arm 环境实遇）dlopen 报
#    "version 'GLIBCXX_3.4.26' not found"。
# 3) --whole-archive 保证各格式的 REGISTER_PAIMON_FACTORY 注册构造函数全部保留，
#    dlopen 时即完成注册，不再需要同伴 .so（ob_ext_plugin.cpp 中的
#    obext_load_companions 已随本改动移除）。
# 注意：此重链接不能加 -Wl,--exclude-libs,ALL —— 这里所有代码都来自 .a，该
# flag 会把 paimon::* 也一并隐藏，导致导出符号为 0（符号收敛由 symbols.map 负责）。
PAIMON_A="relwithdebinfo/libpaimon.a \
          relwithdebinfo/libpaimon_parquet_file_format.a \
          relwithdebinfo/libpaimon_orc_file_format.a \
          relwithdebinfo/libpaimon_avro_file_format.a \
          relwithdebinfo/libpaimon_blob_file_format.a \
          relwithdebinfo/libpaimon_file_index.a \
          relwithdebinfo/libpaimon_local_file_system.a"

# libpaimon.a 已含 offset/union_global_index_reader.cpp.o，从
# libpaimon_global_index.a 里剔除，避免 --whole-archive 下重复定义
mkdir bigso_tmp
( cd bigso_tmp && ar x ../relwithdebinfo/libpaimon_global_index.a \
  && rm -f offset_global_index_reader.cpp.o union_global_index_reader.cpp.o \
  && ar crs ../relwithdebinfo/libpaimon_global_index_monolith.a *.o )

# 第三方 .a 列表从各 paimon *_shared target 的 link.txt 提取（paimon 自身在其中
# 以 .so 出现，天然被排除），避免手写列表随上游依赖变化而漂移
grep -h -o '[^ ]*\.a\b' $(find src/paimon -path '*_shared.dir/link.txt') \
  | xargs -n1 basename | sort -u > bigso_tmp/3rd_names.txt
: > bigso_tmp/3rd_resolved.txt
while read -r n; do
  p=$(find . -path '*-install/*' -name "$n" | head -1)
  [ -z "$p" ] && p=$(find . -name "$n" | head -1)
  if [ -z "$p" ]; then echo "ERROR: third-party archive $n not found"; exit 1; fi
  echo "$p" >> bigso_tmp/3rd_resolved.txt
done < bigso_tmp/3rd_names.txt

$CXX -shared -fPIC -O2 -fstack-protector-strong \
  -o relwithdebinfo/lib_ob_paimon.so \
  -Wl,--whole-archive ${PAIMON_A} \
      relwithdebinfo/libpaimon_global_index_monolith.a \
  -Wl,--no-whole-archive \
  -Wl,--start-group $(cat bigso_tmp/3rd_resolved.txt) -Wl,--end-group \
  -Wl,--version-script=../src/paimon/symbols.map \
  -Wl,-Bsymbolic -Wl,-z,defs -Wl,--gc-sections -Wl,-z,noexecstack -Wl,-z,now \
  -static-libstdc++ -static-libgcc -Wl,-rpath,\$ORIGIN \
  -ldl -lpthread -lm -lrt
rm -rf bigso_tmp

make install

# OB 外表插件按 soname 规约 lib_ob_<name>.so 用 dlopen 加载插件（见 OB 侧
# ob_ext_plugin_loader.cpp 的 build_soname()）。单体 .so 装成 libpaimon.so
# （PaimonConfig.cmake 的 IMPORTED_LOCATION 指向它），再复制为 lib_ob_paimon.so。
# 同伴 .so（libpaimon_parquet_file_format.so 等）不再安装 —— 所有工厂已在单体
# 内注册。构建产物带 -g 约 1.4G，先 strip 到与既有 RPM 一致的 ~43M。
PAIMON_LIBDIR=${RPM_BUILD_ROOT}/%{_prefix}/lib64
cp -a relwithdebinfo/lib_ob_paimon.so ${PAIMON_LIBDIR}/libpaimon.so
strip ${PAIMON_LIBDIR}/libpaimon.so
cp -a ${PAIMON_LIBDIR}/libpaimon.so ${PAIMON_LIBDIR}/lib_ob_paimon.so
rm -f ${PAIMON_LIBDIR}/libpaimon_parquet_file_format.so \
      ${PAIMON_LIBDIR}/libpaimon_orc_file_format.so \
      ${PAIMON_LIBDIR}/libpaimon_avro_file_format.so \
      ${PAIMON_LIBDIR}/libpaimon_blob_file_format.so \
      ${PAIMON_LIBDIR}/libpaimon_file_index.so \
      ${PAIMON_LIBDIR}/libpaimon_global_index.so \
      ${PAIMON_LIBDIR}/libpaimon_local_file_system.so

%files

%defattr(-,root,root)
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Thu Aug 20 2026 OceanBase Deps
- ship one monolithic lib_ob_paimon.so instead of libpaimon.so + companion
  libpaimon_*.so. The chain of reasons:
  1) The plugin must not ride on the host's libstdc++.so.6: on hosts with an
     older runtime (seen on arm) dlopen fails with "version 'GLIBCXX_3.4.26'
     not found". Hence -static-libstdc++ -static-libgcc.
  2) But one static libstdc++ PER DSO is a hazard of its own: symbols.map
     hides it, so each .so would own a private empty-rep and private typeinfo.
     Passing std::string across DSOs (as common as an OK Status with an empty
     message) then corrupts refcount/static storage, and exceptions escape
     catch blocks. A single DSO holds exactly one libstdc++ copy, so string
     and exception semantics stay consistent -- this is why we merge instead
     of just adding -static-libstdc++ to every companion .so.
  3) --whole-archive keeps the REGISTER_PAIMON_FACTORY constructors, so all
     format factories self-register at dlopen time; the companion-dlopen
     constructor in ob_ext_plugin.cpp is removed together with the companion
     .so files.

* Thu Apr 30 2026 OceanBase Deps
- link shared libs with -static-libstdc++ -static-libgcc for portable libstdc++/libgcc

* Fri Mar 27 2026 OceanBase Deps
- initial devdeps-paimon-cpp 0.1.1
