#!/bin/bash
#
# Build gRPC (static) for Android arm64-v8a — Android/NDK equivalent of the
# Linux RPM %install flow:
#   1) c-ares  -> install prefix, remove third_party/cares/cares
#   2) protobuf -> install prefix, remove third_party/protobuf
#   3) gRPC CMake: protobuf/c-ares from CONFIG (staging); zlib/re2/absl as module (third_party);
#      TLS via OpenSSL from Oceanbase devdeps tarball (gRPC_SSL_PROVIDER=package), not BoringSSL module.
#
# Differs from RPM where required for Android:
#   - Two-pass cross-compile: host protoc + grpc_cpp_plugin, then target libprotobuf/libgrpc++
#     (see script block comment before HOST_PROTOC_BUILD).
#   - Target protobuf: -Dprotobuf_BUILD_PROTOC=OFF and -Dprotobuf_PROTOC_EXECUTABLE=...
#   - Every configure uses NDK android.toolchain.cmake (run_android_cmake).
#   - No deps required under PREFIX before build: zlib/re2/absl from gRPC third_party; OpenSSL from
#     prebuilt tarball (override URL with GRPC_OPENSSL_URL). install_to_prefix still copies this
#     package into shared PREFIX afterward for downstream scripts.
#
source "$(dirname "$0")/common.sh"

NAME="grpc"
VERSION="1.46.7"

# Prebuilt OpenSSL for Android arm64 (same layout as ndk/common.sh package_dep).
GRPC_OPENSSL_URL="${GRPC_OPENSSL_URL:-https://mirrors.aliyun.com/oceanbase/development-kit/android/26/arm64/devdeps-openssl-1.1.1u-20260309.tar.gz}"
GRPC_OPENSSL_PKGROOT="devdeps-openssl-1.1.1u"
OPENSSL_ROOT_DIR="$BUILD_DIR/_prebuilt_openssl/$GRPC_OPENSSL_PKGROOT/usr/local/oceanbase/deps/devel"

echo "=== Building $NAME $VERSION ==="

_cache_file="$BUILD_DIR/_cache/$(basename "$GRPC_OPENSSL_URL")"
mkdir -p "$BUILD_DIR/_cache" "$BUILD_DIR/_prebuilt_openssl"
if [[ ! -f "$_cache_file" ]]; then
	echo "Downloading OpenSSL devdeps: $GRPC_OPENSSL_URL"
	curl -fSL --retry 3 -o "$_cache_file.part" "$GRPC_OPENSSL_URL"
	mv "$_cache_file.part" "$_cache_file"
fi
if [[ ! -f "$OPENSSL_ROOT_DIR/lib/libssl.a" ]]; then
	rm -rf "$BUILD_DIR/_prebuilt_openssl/$GRPC_OPENSSL_PKGROOT"
	tar -xzf "$_cache_file" -C "$BUILD_DIR/_prebuilt_openssl"
fi
for f in "$OPENSSL_ROOT_DIR/lib/libssl.a" "$OPENSSL_ROOT_DIR/lib/libcrypto.a"; do
	if [[ ! -f "$f" ]]; then
		echo "ERROR: missing $f (expected under $OPENSSL_ROOT_DIR after extracting tarball)"
		exit 1
	fi
done
echo "Using OpenSSL: $OPENSSL_ROOT_DIR"

GRPC_SRC="$SOURCES_DIR/grpc"
if [[ ! -d "$GRPC_SRC" ]]; then
	echo "ERROR: $GRPC_SRC not found. Run: git submodule update --init sources/grpc"
	exit 1
fi
(
	cd "$GRPC_SRC"
	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		echo "ERROR: $GRPC_SRC is not a valid git checkout."
		exit 1
	fi
	git fetch origin --tags || true
	git checkout "v$VERSION"
	git submodule sync --recursive
	git submodule update --init --recursive
)

if [[ ! -f "$GRPC_SRC/third_party/protobuf/cmake/CMakeLists.txt" ]]; then
	echo "ERROR: $GRPC_SRC/third_party/protobuf is still empty (no cmake/CMakeLists.txt)."
	echo "  From repo root: git submodule update --init --recursive sources/grpc"
	echo "  Then: cd $GRPC_SRC && git submodule sync --recursive && git submodule update --init --recursive"
	exit 1
fi

NDK_CMAKE=(
	"-DCMAKE_TOOLCHAIN_FILE=$NDK_TOOLCHAIN_FILE"
	"-DANDROID_ABI=$ANDROID_ABI"
	"-DANDROID_PLATFORM=$ANDROID_PLATFORM"
	"-DCMAKE_POLICY_VERSION_MINIMUM=$CMAKE_POLICY_VERSION_MINIMUM"
)

run_android_cmake() {
	(
		unset CC CXX CPP AR AS RANLIB STRIP LD
		unset CFLAGS CXXFLAGS CPPFLAGS LDFLAGS
		cmake "$@"
	)
}

# ---------------------------------------------------------------------------
# 交叉编译分工（protobuf / gRPC 会各出现两次 CMake，但不是重复编同一产物）：
#   - 宿主机（Mac）：必须能执行的代码生成工具 —— protoc、grpc_cpp_plugin。
#     Android 版可执行文件不能在构建机上跑，因此不能指望在 NDK 构建里顺带编出 protoc。
#   - 目标机（aarch64 Android）：libprotobuf、libgrpc++ 等静态库，全程用 run_android_cmake。
# ---------------------------------------------------------------------------

# --- 宿主机：仅构建 protoc（与 RPM 同源树；禁止走 NDK 编译器）---
HOST_PROTOC_BUILD="$BUILD_DIR/grpc_host_protoc"
rm -rf "$HOST_PROTOC_BUILD"
HOST_CC=$(command -v clang || command -v cc)
HOST_CXX=$(command -v clang++ || command -v c++)
(
	unset CC CXX CPP AR AS RANLIB STRIP LD
	unset CFLAGS CXXFLAGS CPPFLAGS LDFLAGS
	cmake -S "$GRPC_SRC/third_party/protobuf/cmake" -B "$HOST_PROTOC_BUILD" \
		-DCMAKE_C_COMPILER="$HOST_CC" \
		-DCMAKE_CXX_COMPILER="$HOST_CXX" \
		-DCMAKE_BUILD_TYPE=Release \
		-Dprotobuf_BUILD_TESTS=OFF \
		-Dprotobuf_WITH_ZLIB=OFF
)
cmake --build "$HOST_PROTOC_BUILD" --target protoc -j"${CPU_CORES}"
PROTOC_EXE=""
[[ -x "$HOST_PROTOC_BUILD/protoc" ]] && PROTOC_EXE="$HOST_PROTOC_BUILD/protoc"
[[ -z "$PROTOC_EXE" && -x "$HOST_PROTOC_BUILD/Release/protoc" ]] && PROTOC_EXE="$HOST_PROTOC_BUILD/Release/protoc"
[[ -z "$PROTOC_EXE" ]] && PROTOC_EXE=$(find "$HOST_PROTOC_BUILD" -name protoc -type f -perm -111 2>/dev/null | head -1)
if [[ -z "$PROTOC_EXE" || ! -x "$PROTOC_EXE" ]]; then
	echo "ERROR: failed to build host protoc"
	exit 1
fi
echo "Host protoc: $PROTOC_EXE"
export PATH="$(dirname "$PROTOC_EXE"):$PATH"

# --- 宿主机：仅构建 grpc_cpp_plugin ---
# Android 工程 CMAKE_CROSSCOMPILING=ON 时，protobuf_generate_grpc_cpp() 用 find_program 找插件；
# 若 PATH 上没有可在本机运行的 grpc_cpp_plugin，会变为 _gRPC_CPP_PLUGIN-NOTFOUND。
# 下面只 --target grpc_cpp_plugin，不编 Android 用的 libgrpc++。
HOST_GRPC_TOOLS="$BUILD_DIR/grpc_host_tools"
rm -rf "$HOST_GRPC_TOOLS"
(
	unset CC CXX CPP AR AS RANLIB STRIP LD
	unset CFLAGS CXXFLAGS CPPFLAGS LDFLAGS
	unset CMAKE_TOOLCHAIN_FILE ANDROID_NDK ANDROID_NDK_HOME
	cmake -S "$GRPC_SRC" -B "$HOST_GRPC_TOOLS" \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_C_COMPILER="$HOST_CC" \
		-DCMAKE_CXX_COMPILER="$HOST_CXX" \
		-DgRPC_BUILD_TESTS=OFF \
		-DgRPC_INSTALL=OFF \
		-DgRPC_BUILD_CODEGEN=ON \
		-DgRPC_BUILD_GRPC_CPP_PLUGIN=ON \
		-DgRPC_BUILD_GRPC_CSHARP_PLUGIN=OFF \
		-DgRPC_BUILD_GRPC_NODE_PLUGIN=OFF \
		-DgRPC_BUILD_GRPC_OBJECTIVE_C_PLUGIN=OFF \
		-DgRPC_BUILD_GRPC_PHP_PLUGIN=OFF \
		-DgRPC_BUILD_GRPC_PYTHON_PLUGIN=OFF \
		-DgRPC_BUILD_GRPC_RUBY_PLUGIN=OFF \
		-DgRPC_BUILD_CSHARP_EXT=OFF
)
if ! cmake --build "$HOST_GRPC_TOOLS" --target grpc_cpp_plugin -j"${CPU_CORES}"; then
	echo "Host grpc_cpp_plugin parallel build failed; retry -j1:"
	cmake --build "$HOST_GRPC_TOOLS" --target grpc_cpp_plugin -j1
	exit 1
fi
GRPC_CPP_PLUGIN_EXE=""
for cand in "$HOST_GRPC_TOOLS/grpc_cpp_plugin" "$HOST_GRPC_TOOLS/Release/grpc_cpp_plugin" "$HOST_GRPC_TOOLS/Debug/grpc_cpp_plugin"; do
	if [[ -x "$cand" ]]; then
		GRPC_CPP_PLUGIN_EXE="$cand"
		break
	fi
done
if [[ -z "$GRPC_CPP_PLUGIN_EXE" ]]; then
	GRPC_CPP_PLUGIN_EXE=$(find "$HOST_GRPC_TOOLS" -name grpc_cpp_plugin -type f 2>/dev/null | head -1)
fi
if [[ -z "$GRPC_CPP_PLUGIN_EXE" || ! -f "$GRPC_CPP_PLUGIN_EXE" ]]; then
	echo "ERROR: host grpc_cpp_plugin not found under $HOST_GRPC_TOOLS"
	exit 1
fi
chmod +x "$GRPC_CPP_PLUGIN_EXE" 2>/dev/null || true
HOST_PLUGIN_BIN="$BUILD_DIR/grpc_host_plugin_bin"
rm -rf "$HOST_PLUGIN_BIN" && mkdir -p "$HOST_PLUGIN_BIN"
# 固定名为 grpc_cpp_plugin，保证 find_program 与生成规则能命中 PATH。
ln -sf "$GRPC_CPP_PLUGIN_EXE" "$HOST_PLUGIN_BIN/grpc_cpp_plugin"
export PATH="$HOST_PLUGIN_BIN:$PATH"
echo "Host grpc_cpp_plugin: $GRPC_CPP_PLUGIN_EXE"

SRC=$(prepare_source grpc)
rm -rf "$SRC/.git"
cd "$SRC"

# SRC is a full copy of $GRPC_SRC (same path) after submodule update above; no second sync needed.
for _need in \
	"$SRC/third_party/protobuf/cmake/CMakeLists.txt" \
	"$SRC/third_party/cares/cares/CMakeLists.txt" \
	"$SRC/third_party/zlib/zlib.h"
do
	if [[ ! -f "$_need" ]]; then
		echo "ERROR: missing $_need after prepare_source."
		echo "  From repo root: git submodule update --init --recursive sources/grpc"
		exit 1
	fi
done

# Bundled zlib's zlib.map lists gz_intmax as local, but that symbol is only
# emitted when INT_MAX is undefined (see gzguts.h). NDK/clang always have
# INT_MAX, so lld fails: "version script assignment ... gz_intmax ... symbol not defined".
ZLIB_MAP="$SRC/third_party/zlib/zlib.map"
if [[ -f "$ZLIB_MAP" ]] && grep -q '^[[:space:]]*gz_intmax;[[:space:]]*$' "$ZLIB_MAP"; then
	echo "Patching third_party/zlib/zlib.map (drop gz_intmax for lld)..."
	grep -v '^[[:space:]]*gz_intmax;[[:space:]]*$' "$ZLIB_MAP" >"${ZLIB_MAP}.tmp"
	mv "${ZLIB_MAP}.tmp" "$ZLIB_MAP"
fi

# grpcpp_channelz / grpc++_reflection are gated on gRPC_BUILD_CODEGEN; CODEGEN=ON
# breaks NDK 27 + bundled Abseil. Patch builds them with CODEGEN=OFF; host grpc_cpp_plugin
# above satisfies protoc-gen-grpc for gens/*.grpc.pb.cc.
PATCH_DIR="$OB_DEPS_DIR/patch"
GRPC_PATCH="$PATCH_DIR/grpc-${VERSION}-grpcpp-channelz-without-codegen.patch"
if [[ ! -f "$GRPC_PATCH" ]]; then
	echo "ERROR: missing $GRPC_PATCH"
	exit 1
fi
echo "Applying $(basename "$GRPC_PATCH") ..."
patch -p1 -d "$SRC" -i "$GRPC_PATCH"

PROTOC_CROSS_PATCH="$PATCH_DIR/grpc-${VERSION}-protobuf-host-protoc-cross.patch"
if [[ ! -f "$PROTOC_CROSS_PATCH" ]]; then
	echo "ERROR: missing $PROTOC_CROSS_PATCH"
	exit 1
fi
echo "Applying $(basename "$PROTOC_CROSS_PATCH") ..."
patch -p1 -d "$SRC" -i "$PROTOC_CROSS_PATCH"

STAGING="$BUILD_DIR/${NAME}_staging"
rm -rf "$STAGING" && mkdir -p "$STAGING"

# --- c-ares (same as RPM: static PIC into prefix, then wipe tree) ---
CARES_BUILD="$BUILD_DIR/grpc_cares"
rm -rf "$CARES_BUILD"
run_android_cmake -S "$SRC/third_party/cares/cares" -B "$CARES_BUILD" \
	"${NDK_CMAKE[@]}" \
	-DCMAKE_BUILD_TYPE=RelWithDebInfo \
	-DCMAKE_INSTALL_PREFIX="$STAGING" \
	-DCARES_STATIC=ON \
	-DCARES_SHARED=OFF \
	-DCARES_STATIC_PIC=ON
cmake --build "$CARES_BUILD" -j"${CPU_CORES}"
cmake --install "$CARES_BUILD"
# rm -rf "$SRC/third_party/cares/cares"

# --- Android 目标：protobuf 库（与上面宿主机 protoc 不同：这里编 libprotobuf 等，不编 protoc）---
# 代码生成由 -Dprotobuf_PROTOC_EXECUTABLE 指向上面的宿主机 protoc。
PB_BUILD="$BUILD_DIR/grpc_protobuf_target"
rm -rf "$PB_BUILD"
run_android_cmake -S "$SRC/third_party/protobuf/cmake" -B "$PB_BUILD" \
	"${NDK_CMAKE[@]}" \
	-DCMAKE_BUILD_TYPE=RelWithDebInfo \
	-DCMAKE_INSTALL_PREFIX="$STAGING" \
	-Dprotobuf_BUILD_TESTS=OFF \
	-Dprotobuf_BUILD_PROTOC=OFF \
	-Dprotobuf_PROTOC_EXECUTABLE="$PROTOC_EXE" \
	-Dprotobuf_WITH_ZLIB=OFF
cmake --build "$PB_BUILD" -j"${CPU_CORES}"
cmake --install "$PB_BUILD"
# rm -rf "$SRC/third_party/protobuf"

# --- Android 目标：gRPC 静态库（与上面宿主机 grpc_cpp_plugin 不同：这里编 libgrpc++ 等）---
# gRPC_*_PROVIDER：protobuf/c-ares 已装入 STAGING，用 CONFIG；zlib/re2/absl 用源码树 module；
# SSL 用 OPENSSL_* 指向预置包。勿对 cares/protobuf 再设 module，否则缺 add_subdirectory 路径。
GRPC_BUILD="$BUILD_DIR/grpc_cmake"
rm -rf "$GRPC_BUILD"
run_android_cmake -S "$SRC" -B "$GRPC_BUILD" \
	"${NDK_CMAKE[@]}" \
	-DCMAKE_BUILD_TYPE=RelWithDebInfo \
	-DCMAKE_INSTALL_PREFIX="$STAGING" \
	-DCMAKE_PREFIX_PATH="$STAGING;$OPENSSL_ROOT_DIR" \
	-DCMAKE_PROGRAM_PATH="$(dirname "$PROTOC_EXE")" \
	-DOPENSSL_ROOT_DIR="$OPENSSL_ROOT_DIR" \
	-DOPENSSL_INCLUDE_DIR="$OPENSSL_ROOT_DIR/include" \
	-DOPENSSL_CRYPTO_LIBRARY="$OPENSSL_ROOT_DIR/lib/libcrypto.a" \
	-DOPENSSL_SSL_LIBRARY="$OPENSSL_ROOT_DIR/lib/libssl.a" \
	-Dc-ares_DIR="$STAGING/lib/cmake/c-ares" \
	-DProtobuf_DIR="$STAGING/lib/cmake/protobuf" \
	-DgRPC_INSTALL=ON \
	-DgRPC_BUILD_TESTS=OFF \
	-DgRPC_BUILD_CODEGEN=OFF \
	-DgRPC_PROTOBUF_PROVIDER=module \
	-DgRPC_PROTOBUF_PACKAGE_TYPE=CONFIG \
	-DgRPC_ZLIB_PROVIDER=module \
	-DgRPC_CARES_PROVIDER=module \
	-DgRPC_SSL_PROVIDER=package \
	-DgRPC_RE2_PROVIDER=module \
	-DgRPC_ABSL_PROVIDER=module \
	-Dprotobuf_PROTOC_EXECUTABLE="$PROTOC_EXE" \
	-DBUILD_SHARED_LIBS=OFF

if ! cmake --build "$GRPC_BUILD" -j"${CPU_CORES}"; then
	echo "Parallel gRPC build failed; re-running with -j1 to surface the first error:"
	cmake --build "$GRPC_BUILD" -j1
	exit 1
fi
cmake --install "$GRPC_BUILD"

for _need in libgrpcpp_channelz.a libgrpc++_reflection.a; do
	if [[ ! -f "$STAGING/lib/$_need" ]]; then
		echo "ERROR: $STAGING/lib/$_need missing after install."
		echo "  Need host grpc_cpp_plugin on PATH at configure time; patch grpc CMake; not protobuf-lite."
		exit 1
	fi
done

GRPC_SUB="$STAGING/lib/grpc"
mkdir -p "$GRPC_SUB"
shopt -s nullglob
for f in "$STAGING/lib"/*.a; do mv "$f" "$GRPC_SUB/"; done
for f in "$STAGING/lib"/*.so; do mv "$f" "$GRPC_SUB/"; done
shopt -u nullglob
[[ -d "$STAGING/lib/cmake" ]] && mv "$STAGING/lib/cmake" "$GRPC_SUB/"
[[ -d "$STAGING/lib/pkgconfig" ]] && mv "$STAGING/lib/pkgconfig" "$GRPC_SUB/"

install_to_prefix "$STAGING"
package_dep "$NAME" "$VERSION" "$STAGING"
echo "=== $NAME $VERSION done ==="
