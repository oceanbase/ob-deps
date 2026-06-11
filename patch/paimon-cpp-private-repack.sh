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
# 2. 如果 Paimon 后续只是升级了 Arrow/Avro/ORC/Protobuf 等已有依赖，
#    新增的同 namespace 符号通常会被 cpp_tokens/c_prefixes 自动匹配，
#    不需要维护具体符号列表。
# 3. 如果 Paimon 后续新增了新的 .a 依赖，需要先确认它会进入 OB 最终
#    静态链接闭包，然后把该 archive 加到 archives 列表。否则可能出现
#    undefined symbol，或者新依赖未私有化导致 duplicate symbol。
# 4. 如果新增依赖和 OB 有新的符号冲突，需要把对应 C++ 根 namespace
#    的 mangled token 加到 cpp_root_tokens，或把 C 符号前缀加到 c_prefixes。
#    C++ 符号必须只按“根 namespace”匹配，不要匹配模板参数里的 namespace。
#    例如 std::future<orc::...> 的根 namespace 是 std，不应该因为模板参数
#    里出现 orc:: 就被私有化，否则可能影响 libstdc++ 符号和 BOLT 分析。
# 5. 不要私有化 paimon::*。OB 通过 Paimon 头文件直接调用 paimon:: API，
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

archives=(
  "${paimon_core_lib_dir}/libpaimon.a"
  "${paimon_core_lib_dir}/libpaimon_parquet_file_format.a"
  "${paimon_core_lib_dir}/libpaimon_avro_file_format.a"
  "${paimon_core_lib_dir}/libpaimon_orc_file_format.a"
  "${paimon_core_lib_dir}/libpaimon_blob_file_format.a"
  "${paimon_core_lib_dir}/libpaimon_local_file_system.a"
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
  "${paimon_deps_lib_dir}/libroaring_bitmap.a"
)

existing_archives=()
for archive in "${archives[@]}"; do
  if [[ -f "${archive}" ]]; then
    existing_archives+=("${archive}")
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
    | awk '{ if (NF > 0) print $NF }' >> "${private_symbols}"
done

"${python_bin}" - "${private_symbols}" "${private_map}" <<'PY'
import sys

symbols_path, map_path = sys.argv[1], sys.argv[2]

cpp_root_tokens = (
    "5arrow",
    "7parquet",
    "4avro",
    "3orc",
    "6google",
    "3fmt",
    "3tbb",
    "3re2",
    "7roaring",
    "6snappy",
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

def should_private_cpp(sym):
    # Normal nested names, e.g. _ZN5arrow..., _ZNK3orc...
    if sym.startswith("_Z") and nested_name_has_root(sym[2:]):
        return True
    # Special names for vtable/typeinfo/typeinfo-name/VTT.
    for prefix in ("_ZTV", "_ZTI", "_ZTS", "_ZTT"):
        if sym.startswith(prefix) and nested_name_has_root(sym[len(prefix):]):
            return True
    # Local statics inside private dependency functions, e.g.
    # _ZZN5arrow...E... and their guard variables _ZGVZN5arrow...E...
    if sym.startswith("_ZZ") and nested_name_has_root(sym[3:]):
        return True
    if sym.startswith("_ZGVZ") and nested_name_has_root(sym[5:]):
        return True
    # Guard variables for namespace-scope statics in private dependencies.
    if sym.startswith("_ZGV") and nested_name_has_root(sym[4:]):
        return True
    # Thunks encode the target function after the thunk prefix. Only match when
    # the target function's root namespace is private.
    thunk_pos = sym.find("_N")
    if sym.startswith(("_ZTh", "_ZTv", "_ZTc")) and thunk_pos >= 0:
        return nested_name_has_root(sym[thunk_pos + 1:])
    return False

def should_private(sym):
    if not sym or sym == "-" or sym.startswith("paimon_priv_"):
        return False
    if sym.startswith("_Z"):
        return should_private_cpp(sym)
    return any(sym.startswith(prefix) for prefix in c_prefixes)

symbols = set()
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

rm -f "${private_symbols}"
