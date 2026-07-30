#!/bin/sh

set -eu

CUR_DIR=$(dirname "$(readlink -f "$0")")
ROOT_DIR=$CUR_DIR/..
PROJECT_DIR=${1:-"$ROOT_DIR"}
PROJECT_NAME=${2:-"devdeps-libxslt-static"}
VERSION=${3:-"1.1.34"}
RELEASE=${4:-"4"}
LIBXML2_VERSION=${5:-"2.15.3"}
LIBXML2_RELEASE=${6:-"3"}
VERSION_SERIES=${VERSION%.*}
SOURCE_ARCHIVE="libxslt-$VERSION.tar.xz"
SOURCE_SHA256="28c47db33ab4daefa6232f31ccb3c65260c825151ec86ec461355247f3f56824"
DIST_TAG=$(rpm --eval '%{?dist}')
ARCH=$(rpm --eval '%{_arch}')
DEFAULT_LIBXML2_RPM="$CUR_DIR/devdeps-libxml2-$LIBXML2_VERSION-$LIBXML2_RELEASE$DIST_TAG.$ARCH.rpm"
REQUESTED_LIBXML2_RPM=${LIBXML2_RPM:-}
REQUESTED_LIBXML2_PREFIX=${LIBXML2_PREFIX:-}
LIBXML2_RPM=
LIBXML2_PREFIX=
LIBXML2_ROOT=
LIBXML2_RPM_MIRROR=${LIBXML2_RPM_MIRROR:-"https://mirrors.aliyun.com/oceanbase/development-kit/el"}

LIBXML2_MAJOR=${LIBXML2_VERSION%%.*}
LIBXML2_VERSION_REST=${LIBXML2_VERSION#*.}
LIBXML2_MINOR=${LIBXML2_VERSION_REST%%.*}
LIBXML2_MICRO=${LIBXML2_VERSION_REST#*.}
if [ "$LIBXML2_VERSION" != "$LIBXML2_MAJOR.$LIBXML2_MINOR.$LIBXML2_MICRO" ]; then
    echo "Invalid libxml2 version: $LIBXML2_VERSION" >&2
    exit 1
fi
case "$LIBXML2_MAJOR:$LIBXML2_MINOR:$LIBXML2_MICRO" in
    *[!0-9:]* | :* | *::* | *:)
        echo "Invalid libxml2 version: $LIBXML2_VERSION" >&2
        exit 1
        ;;
esac
LIBXML2_VERSION_NUMBER=$((LIBXML2_MAJOR * 10000 + LIBXML2_MINOR * 100 + LIBXML2_MICRO))

cleanup()
{
    if [ -n "$LIBXML2_ROOT" ] && [ -d "$LIBXML2_ROOT" ]; then
        rm -rf -- "$LIBXML2_ROOT"
    fi
}

libxml2_prefix_is_usable()
{
    local prefix=$1
    local version_header="$prefix/include/libxml2/libxml/xmlversion.h"
    local actual_version

    [ -x "$prefix/bin/xml2-config" ] || return 1
    [ -f "$version_header" ] || return 1
    [ -f "$prefix/lib/libxml2.a" ] || return 1

    actual_version=$(awk '$1 == "#define" && $2 == "LIBXML_VERSION" { print $3; exit }' "$version_header")
    [ "$actual_version" = "$LIBXML2_VERSION_NUMBER" ]
}

select_libxml2_prefix()
{
    local prefix=$1

    if libxml2_prefix_is_usable "$prefix"; then
        export LIBXML2_PREFIX=$prefix
        echo "Using libxml2 $LIBXML2_VERSION from: $LIBXML2_PREFIX"
        return 0
    fi
    return 1
}

use_libxml2_rpm()
{
    local rpm_file=$1
    local extracted_root
    local extracted_prefix
    local rpm_cpio

    [ -f "$rpm_file" ] || return 1

    extracted_root=$(mktemp -d)
    rpm_cpio="$extracted_root/libxml2.cpio"
    if ! rpm2cpio "$rpm_file" > "$rpm_cpio"; then
        echo "Failed to read libxml2 RPM: $rpm_file" >&2
        rm -rf -- "$extracted_root"
        return 1
    fi
    if ! (cd "$extracted_root" && cpio -idm --quiet < "$rpm_cpio"); then
        echo "Failed to extract libxml2 RPM: $rpm_file" >&2
        rm -rf -- "$extracted_root"
        return 1
    fi
    rm -f -- "$rpm_cpio"

    extracted_prefix="$extracted_root/usr/local/oceanbase/deps/devel"
    if ! libxml2_prefix_is_usable "$extracted_prefix"; then
        echo "Ignoring incompatible libxml2 RPM: $rpm_file" >&2
        rm -rf -- "$extracted_root"
        return 1
    fi

    cleanup
    LIBXML2_ROOT=$extracted_root
    LIBXML2_RPM=$rpm_file
    export LIBXML2_PREFIX=$extracted_prefix
    echo "Using libxml2 RPM: $LIBXML2_RPM"
    return 0
}

find_local_libxml2_rpm()
{
    local rpm_file

    if use_libxml2_rpm "$DEFAULT_LIBXML2_RPM"; then
        return 0
    fi

    for rpm_file in "$CUR_DIR"/devdeps-libxml2-"$LIBXML2_VERSION"-"$LIBXML2_RELEASE"*."$ARCH".rpm; do
        [ -f "$rpm_file" ] || continue
        [ "$rpm_file" = "$DEFAULT_LIBXML2_RPM" ] && continue
        if use_libxml2_rpm "$rpm_file"; then
            return 0
        fi
    done

    return 1
}

download_libxml2_rpm()
{
    local os_release
    local try_release
    local try_dist
    local rpm_name
    local rpm_file
    local rpm_tmp
    local rpm_url
    local tried_urls=

    os_release=$(grep -Po '(?<=release )\d+' /etc/redhat-release 2>/dev/null || true)
    if [ -z "$os_release" ] || [ "$os_release" = "3" ]; then
        os_release=8
    fi

    for try_release in "$os_release" 8 7 9; do
        for try_dist in "$DIST_TAG" ".el$try_release" ".al$try_release"; do
            rpm_name="devdeps-libxml2-$LIBXML2_VERSION-$LIBXML2_RELEASE$try_dist.$ARCH.rpm"
            rpm_file="$CUR_DIR/$rpm_name"
            rpm_tmp="$rpm_file.download"
            rpm_url="$LIBXML2_RPM_MIRROR/$try_release/$ARCH/$rpm_name"
            if printf '%s\n' "$tried_urls" | grep -Fqx "$rpm_url"; then
                continue
            fi
            tried_urls="${tried_urls}
$rpm_url"
            echo "Trying libxml2 RPM: $rpm_url"
            if wget -q --timeout=10 --tries=1 "$rpm_url" -O "$rpm_tmp"; then
                mv -f "$rpm_tmp" "$rpm_file"
                if use_libxml2_rpm "$rpm_file"; then
                    return 0
                fi
                rm -f -- "$rpm_file"
            else
                rm -f -- "$rpm_tmp"
            fi
        done
    done

    return 1
}

build_libxml2_rpm()
{
    echo "No usable libxml2 $LIBXML2_VERSION found; building it first"
    if ! bash "$CUR_DIR/devdeps-libxml2-build.sh" \
        "$PROJECT_DIR" "devdeps-libxml2" "$LIBXML2_VERSION" "$LIBXML2_RELEASE"; then
        echo "Failed to build libxml2 $LIBXML2_VERSION" >&2
        return 1
    fi

    if find_local_libxml2_rpm; then
        return 0
    fi

    echo "libxml2 build completed without a usable RPM" >&2
    return 1
}

prepare_libxml2()
{
    local prefix

    if [ -n "$REQUESTED_LIBXML2_PREFIX" ]; then
        if select_libxml2_prefix "$REQUESTED_LIBXML2_PREFIX"; then
            return 0
        fi
        echo "Requested libxml2 prefix is unavailable or incompatible: $REQUESTED_LIBXML2_PREFIX" >&2
    fi

    if [ -n "$REQUESTED_LIBXML2_RPM" ]; then
        if use_libxml2_rpm "$REQUESTED_LIBXML2_RPM"; then
            return 0
        fi
        echo "Requested libxml2 RPM is unavailable or incompatible: $REQUESTED_LIBXML2_RPM" >&2
    fi

    for prefix in \
        "$PROJECT_DIR/deps/3rd/usr/local/oceanbase/deps/devel" \
        "/usr/local/oceanbase/deps/devel"; do
        if select_libxml2_prefix "$prefix"; then
            return 0
        fi
    done

    find_local_libxml2_rpm && return 0
    download_libxml2_rpm && return 0
    build_libxml2_rpm && return 0

    echo "Unable to prepare libxml2 $LIBXML2_VERSION for libxslt" >&2
    return 1
}

trap cleanup 0

if [ -n "${SOURCE_DIR:-}" ] && [ -f "$SOURCE_DIR/$SOURCE_ARCHIVE" ]; then
    cp "$SOURCE_DIR/$SOURCE_ARCHIVE" "$ROOT_DIR/$SOURCE_ARCHIVE"
fi

if [ ! -f "$ROOT_DIR/$SOURCE_ARCHIVE" ]; then
    echo "Download source code"
    wget "https://download.gnome.org/sources/libxslt/$VERSION_SERIES/$SOURCE_ARCHIVE" \
        -O "$ROOT_DIR/$SOURCE_ARCHIVE"
fi
echo "$SOURCE_SHA256  $ROOT_DIR/$SOURCE_ARCHIVE" | sha256sum --check -

if ! prepare_libxml2; then
    exit 1
fi

cd "$CUR_DIR"
bash "$CUR_DIR/rpmbuild.sh" "$PROJECT_DIR" "$PROJECT_NAME" "$VERSION" "$RELEASE"
