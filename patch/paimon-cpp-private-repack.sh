#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' \
"Usage:" \
"  paimon-cpp-private-repack.sh <paimon-core-lib-dir> <paimon-deps-lib-dir>" \
"" \
"Rewrite Paimon static archives in place so Paimon's bundled dependency" \
"symbols can coexist with OceanBase dependencies." \
"" \
"Environment overrides:" \
"  NM       Path to nm, default: /usr/local/oceanbase/devtools/bin/nm" \
"  OBJCOPY  Path to objcopy, default: /usr/local/oceanbase/devtools/bin/objcopy" \
"  AR       Path to ar, default: /usr/local/oceanbase/devtools/bin/ar" \
"  RANLIB   Path to ranlib, default: /usr/local/oceanbase/devtools/bin/ranlib"
}

# 维护原则：
# 1. 这个脚本采用白名单方式处理 Paimon 静态链接闭包中的 archive。
#    这样范围清晰、可控，避免把测试库、工具库或无关 archive 误打进
#    devdeps RPM。
# 2. Paimon 自带的 thirdparty archive 由 Paimon 独占使用，任何全局定义符号
#    都不应该暴露到 OB 的最终链接命名空间。因此 thirdparty archive 的
#    defined global symbols 会全量进入 rename map；这能一次覆盖 ORC/Avro/
#    Protobuf/std weak vtable/typeinfo 等容易漏掉的 ABI 符号。
# 3. Paimon 自身 archive 不能全量改名，因为 OB 会通过 Paimon 头文件直接
#    调用 paimon:: API。Paimon archive 里的依赖符号仍通过 cpp_root_tokens/
#    c_prefixes 以及 thirdparty defined-symbol map 来改名。
# 4. 如果 Paimon 后续只是升级了 Avro/ORC/Protobuf 等已有依赖，thirdparty
#    archive 新增的定义符号会自动被全量私有化，通常不需要维护具体符号列表。
# 5. 如果 Paimon 后续新增了新的 .a 依赖，需要先确认它会进入 OB 最终
#    静态链接闭包，然后按归属加到 paimon_archives 或 thirdparty_archives
#    列表。否则可能出现
#    undefined symbol，或者新依赖未私有化导致 duplicate symbol。
# 6. 如果 Paimon 自身 archive 出现新的依赖符号规则，需要把对应 C++ 根 namespace
#    的 mangled token 加到 cpp_root_tokens，或把 C 符号前缀加到 c_prefixes。
#    C++ 符号必须只按”根 namespace”匹配，不要匹配模板参数里的 namespace。
#    例如 std::future<orc::...> 的根 namespace 是 std，不应该因为模板参数
#    里出现 orc:: 就被私有化，否则可能影响 libstdc++ 符号和 BOLT 分析。
#    同理不能把 3std 加入 cpp_root_tokens 做”全量 std:: 私有化”——
#    paimon:: API 边界上经由 std:: 传参的类型（如 std::shared_ptr<paimon::Table>、
#    std::vector<paimon::ColumnData>）若被重命名会破坏 ABI 边界。
#    但 std:: 模板实例化中含 arrow::/orc:: 等类型时（如
#    std::__shared_ptr<arrow::SimpleRecordBatch>、
#    __gnu_cxx::new_allocator<arrow::SimpleRecordBatch>::construct），
#    它们是 Arrow 内部 weak symbol，链接器可能选择 Paimon 的版本，导致
#    OB 创建的 RecordBatch 携带 Paimon Arrow 的 vtable，Slice 产出 ABI 不兼容
#    的 ArrayData，最终触发 memory_sanity_abort。
#    should_private_cpp 里的 _ZN[K/R/O/V]St/_ZSt 子串规则专门处理此类情况：
#    仅当 std:: 符号的模板参数中含有 cpp_root_tokens 里的 token 时才私有化。
#    由于 6paimon 不在 cpp_root_tokens（注释第7条），std::shared_ptr<paimon::X>
#    等 API 边界类型不会被误命中。
#    查漏方法：nm observer | awk 在 paimon_priv_ 符号地址范围内找无前缀的全局符号。
#    已补充的 namespace/规则：
#      6apache          → apache::thrift:: (libarrow_bundled_dependencies.a)
#      14arrow_vendored → arrow_vendored::date:: / double_conversion:: (libarrow.a)
#      9__gnu_cxx       → __gnu_cxx::new_allocator<arrow::T>::construct (weak symbol 劫持)
#      _ZNSt/_ZNKSt/_ZNRSt/_ZNOSt/_ZNVSt/_ZSt 规则 → std::<T>::method[const/&/&&/volatile] 等含 arrow 模板参数的 std:: weak symbol
# 7. 不要私有化 paimon::*。OB 通过 Paimon 头文件直接调用 paimon:: API，
#    如果 paimon::* 也被 rename，OB 编译出来的原始 paimon:: 符号会链接
#    不上。只有未来 OB 改成 C wrapper 或完整 namespace wrapper 时，才
#    能考虑改这个边界。

if [[ $# -ne 2 ]]; then
  usage >&2
  exit 2
fi

paimon_core_lib_dir="$1"
paimon_deps_lib_dir="$2"

devtools_bin="/usr/local/oceanbase/devtools/bin"
nm_bin="${NM:-${devtools_bin}/llvm-nm}"
objcopy_bin="${OBJCOPY:-${devtools_bin}/llvm-objcopy}"
ar_bin="${AR:-${devtools_bin}/llvm-ar}"
ranlib_bin="${RANLIB:-${devtools_bin}/llvm-ranlib}"
python_bin="${PYTHON:-}"

if [[ -z "${python_bin}" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    python_bin="$(command -v python3)"
  elif command -v python >/dev/null 2>&1; then
    python_bin="$(command -v python)"
  else
    echo "python or python3 is required for private repack" >&2
    exit 1
  fi
fi

private_map="${paimon_deps_lib_dir}/paimon_private_rename.map"
private_symbols="${paimon_deps_lib_dir}/.paimon_private_symbols.txt"
private_defined_symbols="${paimon_deps_lib_dir}/.paimon_private_defined_symbols.txt"

paimon_archives=(
  "${paimon_core_lib_dir}/libpaimon.a"
  "${paimon_core_lib_dir}/libpaimon_parquet_file_format.a"
  "${paimon_core_lib_dir}/libpaimon_avro_file_format.a"
  "${paimon_core_lib_dir}/libpaimon_orc_file_format.a"
  "${paimon_core_lib_dir}/libpaimon_blob_file_format.a"
  "${paimon_core_lib_dir}/libpaimon_local_file_system.a"
)

thirdparty_archives=(
  "${paimon_deps_lib_dir}/libarrow.a"
  "${paimon_deps_lib_dir}/libparquet.a"
  "${paimon_deps_lib_dir}/libarrow_dataset.a"
  "${paimon_deps_lib_dir}/libarrow_acero.a"
  "${paimon_deps_lib_dir}/libarrow_bundled_dependencies.a"
  "${paimon_deps_lib_dir}/libavrocpp_s.a"
  "${paimon_deps_lib_dir}/liborc.a"
  "${paimon_deps_lib_dir}/libprotobuf.a"
  "${paimon_deps_lib_dir}/libsnappy.a"
  "${paimon_deps_lib_dir}/libzstd.a"
  "${paimon_deps_lib_dir}/liblz4.a"
  "${paimon_deps_lib_dir}/libz.a"
  "${paimon_deps_lib_dir}/libre2.a"
  "${paimon_deps_lib_dir}/libfmt.a"
  "${paimon_deps_lib_dir}/libglog.a"
  "${paimon_deps_lib_dir}/libtbb.a"
  "${paimon_deps_lib_dir}/libtbbmalloc.a"
  "${paimon_deps_lib_dir}/libroaring_bitmap.a"
)

is_arrow_archive() {
  local archive_name
  archive_name="$(basename "$1")"
  case "${archive_name}" in
    libarrow.a|libparquet.a|libarrow_dataset.a|libarrow_acero.a|libarrow_bundled_dependencies.a)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

existing_archives=()
existing_thirdparty_archives=()

for archive in "${paimon_archives[@]}"; do
  if [[ -f "${archive}" ]]; then
    existing_archives+=("${archive}")
  else
    echo "Skip missing Paimon archive: ${archive}"
  fi
done

for archive in "${thirdparty_archives[@]}"; do
  if [[ "${PAIMON_PRIVATE_REPACK_SKIP_ARROW:-0}" == "1" ]] && is_arrow_archive "${archive}"; then
    echo "Skip Arrow/Parquet archive in system Arrow mode: ${archive}"
    continue
  fi
  if [[ -f "${archive}" ]]; then
    existing_archives+=("${archive}")
    existing_thirdparty_archives+=("${archive}")
  else
    echo "Skip missing Paimon archive: ${archive}"
  fi
done

if [[ "${#existing_archives[@]}" == "0" ]]; then
  echo "No Paimon archives found for private repack" >&2
  exit 1
fi

: > "${private_symbols}"
for archive in "${existing_archives[@]}"; do
  "${nm_bin}" -g "${archive}" 2>/dev/null \
    | awk '{ if (NF >= 2) print $NF }' >> "${private_symbols}"
done

: > "${private_defined_symbols}"
for archive in "${existing_thirdparty_archives[@]}"; do
  "${nm_bin}" -g --defined-only "${archive}" 2>/dev/null \
    | awk '{ if (NF >= 2) print $NF }' >> "${private_defined_symbols}"
done

"${python_bin}" - "${private_symbols}" "${private_defined_symbols}" "${private_map}" <<'PY'
# -*- coding: utf-8 -*-
import os
import sys

symbols_path, defined_symbols_path, map_path = sys.argv[1], sys.argv[2], sys.argv[3]

cpp_root_tokens = (
    "5arrow",
    "7parquet",
    "4avro",
    "3orc",
    "6apache",         # apache::thrift:: (bundled in libarrow_bundled_dependencies.a)
    "14arrow_vendored", # arrow_vendored::date:: / arrow_vendored::double_conversion::
    "6google",
    "3fmt",
    "3tbb",
    "3re2",
    "7roaring",
    "6snappy",
    "9__gnu_cxx",      # __gnu_cxx::new_allocator<arrow::T>::construct — weak symbol
                       # 根因：链接器选了 Paimon 的版本，导致 OB 的 RecordBatch 对象
                       # 携带 Paimon Arrow 的 vtable，Slice 产出 ABI 不兼容的 ArrayData
)

if os.environ.get("PAIMON_PRIVATE_REPACK_SKIP_ARROW") == "1":
    cpp_root_tokens = tuple(
        token for token in cpp_root_tokens
        if token not in ("5arrow", "7parquet", "6apache", "14arrow_vendored", "9__gnu_cxx")
    )

c_prefixes = (
    "snappy_",
    "Brotli",
    "_kBrotli",
    "kBrotli",
    "BZ2_",
    "LZ4",
    "ZSTD",
    "ZSTDMT",
    "ZBUFF",
    "FSEv",
    "HUFv",
    "ZSTDv",
    "_HUF",
    "HUF_",
    "FSE_",
    "XXH",
    "roaring_",
    "croaring_",
    "adler32",
    "compress",
    "crc32",
    "deflate",
    "get_crc_table",
    "gz",
    "inflate",
    "uncompress",
    "zError",
    "z_errmsg",
    "zcalloc",
    "zcfree",
    "zlib",
    "read_long_length_no_check",
    # Intel ISA-L / QPL / accelerator libs bundled in libarrow_bundled_dependencies.a
    "isal_",
    "qpl_",
    "qae_",
    "accfg_",
    "avx512_",
    # zstd internal cross-TU helpers — no ZSTD_ prefix, but conflict with OB's libzstd
    # (OB=1.5.6, Paimon=1.5.7; POOL_s struct layout changed between versions)
    "COVER_",
    "POOL_",
    "HIST_",
    "ZDICT_",
    "divbwt",
    "divsufsort",
    "ERR_getErrorString",
    "g_ZSTD_",
    "g_debuglevel",
    # zlib internal tree functions — conflict with OB's libz (both 1.3.1 today,
    # but rename proactively to guard against future version drift)
    "_tr_",
    "_dist_code",
    "_length_code",
    # protobuf C-linkage type-registration tables generated by protoc
    # (descriptor_table_* / scc_info_* for well-known types and ORC proto schema)
    # conflict with OB's libprotobuf-v371.a (3.7.1) vs Paimon's libprotobuf (3.8.0)
    "descriptor_table_",
    "scc_info_",
)

def nested_name_has_root(s):
    if not s.startswith("N"):
        return False
    idx = 1
    # Itanium ABI nested names may carry cv/ref qualifiers after N, for
    # example _ZNK5arrow... for arrow::Foo::bar() const.
    while idx < len(s) and s[idx] in "KVRrO":
        idx += 1
    return any(s.startswith(token, idx) for token in cpp_root_tokens)

def has_private_root_token(sym):
    return any(token in sym for token in cpp_root_tokens)

def should_private_cpp(sym):
    # Normal nested names: _ZN5arrow..., _ZNK3orc..., etc.
    if sym.startswith("_Z") and nested_name_has_root(sym[2:]):
        return True
    # ABI special symbols for std/libstdc++ template instantiations whose
    # template arguments contain private dependency types.  These are the
    # vtable/typeinfo side of weak std:: template functions such as
    # std::_Sp_counted_ptr_inplace<orc::...>::_M_dispose.  If the functions
    # are renamed but their vtables are not, OB native objects can dispatch
    # into paimon_priv implementations during destruction.
    if sym.startswith(("_ZTV", "_ZTI", "_ZTS", "_ZTT", "_ZTC", "_ZTF")):
        return has_private_root_token(sym)
    # All _ZTX single-discriminator specials where the nested name starts at
    # position 4: vtable (_ZTV), typeinfo (_ZTI/_ZTS), VTT (_ZTT), construction
    # vtable (_ZTC), typeinfo function (_ZTF), and any future _ZTX variants.
    # Thunks (_ZTh/_ZTv/_ZTc) are excluded here; they are handled below.
    if (sym.startswith("_ZT")
            and len(sym) > 4
            and sym[3] not in "hvc"
            and nested_name_has_root(sym[4:])):
        return True
    # Local statics: _ZZN5arrow...
    if sym.startswith("_ZZ") and nested_name_has_root(sym[3:]):
        return True
    # Guard/reference symbols: _ZGVZ has the nested name at position 5;
    # _ZGV, _ZGR, and any future _ZGX variants have it at position 4.
    if sym.startswith("_ZGVZ") and nested_name_has_root(sym[5:]):
        return True
    if sym.startswith("_ZG") and len(sym) > 4 and nested_name_has_root(sym[4:]):
        return True
    # Thunks encode the target function after the thunk prefix.
    thunk_pos = sym.find("_N")
    if sym.startswith(("_ZTh", "_ZTv", "_ZTc")) and thunk_pos >= 0:
        return nested_name_has_root(sym[thunk_pos + 1:])
    # std:: template instantiations whose template parameters include our types.
    # Example: std::__shared_ptr<arrow::SimpleRecordBatch>, or
    #          std::_Hashtable<arrow::FieldPath, ...>.
    # These are weak (W) symbols that the linker can "steal" from Paimon's archives,
    # causing OB's RecordBatch/ArrayData to carry Paimon Arrow's vtable/layout.
    # Root namespace is "std" so nested_name_has_root won't fire; we check whether
    # any of our root tokens appears anywhere inside the mangled name instead.
    # Excluding paimon:: symbols is unnecessary here because paimon:: names start
    # with _ZN6paimon, not _ZNSt / _ZSt.
    if sym.startswith(("_ZNSt", "_ZNKSt", "_ZNRSt", "_ZNOSt", "_ZNVSt", "_ZSt",
                       "_ZN9__gnu_cxx", "_ZNK9__gnu_cxx", "_ZSt")):
        return has_private_root_token(sym)
    # protobuf code-generated type metadata structs: TableStruct_<url-encoded-proto-path>::offsets
    # These use URL-encoded path as struct name (e.g. TableStruct_google_2fprotobuf_2fany_2eproto)
    # so cpp_root_tokens ("6google" etc.) won't match; detect by struct name prefix instead.
    # Conflicts with OB's libprotobuf-v371.a (3.7.1) and liborc's generated code.
    if sym.startswith("_ZN") and "TableStruct_" in sym:
        return True
    return False

def should_private(sym):
    if not sym or sym == "-" or sym.startswith("paimon_priv_"):
        return False
    if sym.startswith("_Z"):
        return should_private_cpp(sym)
    return any(sym.startswith(prefix) for prefix in c_prefixes)

never_private_defined = set((
    "_GLOBAL_OFFSET_TABLE_",
    "__bss_start",
    "__dso_handle",
    "_edata",
    "_end",
    "_fini",
    "_init",
    "_start",
    "main",
))

never_private_defined_prefixes = (
    "__cxa_",
    "__gxx_personality",
    "_Unwind_",
)

def should_private_defined(sym):
    if not sym or sym == "-" or sym.startswith("paimon_priv_"):
        return False
    if sym in never_private_defined:
        return False
    if any(sym.startswith(prefix) for prefix in never_private_defined_prefixes):
        return False
    return True

symbols = set()
with open(defined_symbols_path, "r") as f:
    for line in f:
        sym = line.strip()
        if should_private_defined(sym):
            symbols.add(sym)

with open(symbols_path, "r") as f:
    for line in f:
        sym = line.strip()
        if should_private(sym):
            symbols.add(sym)

with open(map_path, "w") as f:
    for sym in sorted(symbols):
        f.write("%s paimon_priv_%s\n" % (sym, sym))
PY

map_count="$(wc -l < "${private_map}" | tr -d ' ')"
if [[ "${map_count}" == "0" ]]; then
  echo "No Paimon symbols matched private rename rules" >&2
  exit 1
fi
echo "Private Paimon rename symbols: ${map_count}"

repack_one_archive() {
  local archive="$1"
  local tmp_dir="${archive}.private-tmp"
  local extract_dir="${tmp_dir}/extract"
  local object_dir="${tmp_dir}/objects"
  local output_archive="${tmp_dir}/$(basename "${archive}")"

  rm -rf "${tmp_dir}"
  mkdir -p "${extract_dir}" "${object_dir}"

  mapfile -t members < <("${ar_bin}" t "${archive}")
  if [[ "${#members[@]}" == "0" ]]; then
    echo "Archive has no members: ${archive}" >&2
    exit 1
  fi

  declare -A member_instances=()
  local idx=0
  local member
  local instance
  local extracted
  local renamed
  local -a repacked_members=()

  for member in "${members[@]}"; do
    idx=$((idx + 1))
    instance="$(( ${member_instances["${member}"]:-0} + 1 ))"
    member_instances["${member}"]="${instance}"

    rm -f "${extract_dir}/${member}"
    (cd "${extract_dir}" && "${ar_bin}" xN "${instance}" "${archive}" "${member}")
    extracted="${extract_dir}/${member}"
    renamed="${object_dir}/$(printf '%06d' "${idx}")_${member##*/}"
    "${objcopy_bin}" --redefine-syms "${private_map}" "${extracted}" "${renamed}"
    repacked_members+=("${renamed}")
  done

  rm -f "${output_archive}"
  "${ar_bin}" qc "${output_archive}" "${repacked_members[@]}"
  "${ranlib_bin}" "${output_archive}"
  mv -f "${output_archive}" "${archive}"
  rm -rf "${tmp_dir}"
}

for archive in "${existing_archives[@]}"; do
  echo "Private repack Paimon archive: ${archive}"
  repack_one_archive "${archive}"
done

rm -f "${private_symbols}" "${private_defined_symbols}"
