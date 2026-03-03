#!/bin/bash
#
# Build Lua (static) for Android arm64-v8a
#
# Note: The lua/lua GitHub mirror has a flat layout (all .c/.h at root)
# unlike the official tarball which has src/. We handle both layouts.
#
source "$(dirname "$0")/common.sh"

NAME="lua"
VERSION="5.4.6"

echo "=== Building $NAME $VERSION ==="

SRC=$(prepare_source lua)
cd "$SRC"

# The lua GitHub mirror omits lua.hpp (C++ wrapper). Create it if missing.
if [[ ! -f lua.hpp ]] && [[ ! -f src/lua.hpp ]]; then
    cat > lua.hpp <<'LUAHPP'
extern "C" {
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}
LUAHPP
    echo "Created missing lua.hpp"
fi

STAGING="$BUILD_DIR/${NAME}_staging"
rm -rf "$STAGING" && mkdir -p "$STAGING/lib" "$STAGING/include"

# Detect layout: tarball has src/, GitHub mirror has files at root
if [[ -d src ]]; then
    # Tarball layout
    cd src
    TO_INC=$(grep '^TO_INC=' ../Makefile | sed 's/^TO_INC= *//')
    TO_LIB=$(grep '^TO_LIB=' ../Makefile | sed 's/^TO_LIB= *//')

    make -j${CPU_CORES} a \
        CC="$CC" \
        AR="$AR rc" \
        RANLIB="$RANLIB" \
        MYCFLAGS="-fPIC"

    cp $TO_INC "$STAGING/include/"
    cp $TO_LIB "$STAGING/lib/"
else
    # GitHub mirror layout: flat directory with makefile
    # Build liblua.a from core + lib sources
    CORE_SRCS="lapi.c lcode.c lctype.c ldebug.c ldo.c ldump.c lfunc.c lgc.c llex.c lmem.c lobject.c lopcodes.c lparser.c lstate.c lstring.c ltable.c ltm.c lundump.c lvm.c lzio.c"
    LIB_SRCS="lauxlib.c lbaselib.c lcorolib.c ldblib.c liolib.c lmathlib.c loadlib.c loslib.c lstrlib.c ltablib.c lutf8lib.c linit.c"
    HEADERS="lua.h luaconf.h lualib.h lauxlib.h lua.hpp"

    for src in $CORE_SRCS $LIB_SRCS; do
        if [[ -f "$src" ]]; then
            "$CC" -fPIC -std=gnu99 -O2 -Wall -DLUA_COMPAT_5_3 -c "$src"
        fi
    done
    "$AR" rcs liblua.a *.o
    "$RANLIB" liblua.a

    cp liblua.a "$STAGING/lib/"
    for h in $HEADERS; do
        [[ -f "$h" ]] && cp "$h" "$STAGING/include/"
    done
fi

install_to_prefix "$STAGING"
package_dep "$NAME" "$VERSION" "$STAGING"
echo "=== $NAME $VERSION done ==="
