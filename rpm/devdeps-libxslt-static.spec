Name: devdeps-libxslt-static
Version: 1.1.34
Release: %(echo $RELEASE)%{?dist}
Summary: Static libxslt libraries built against the OceanBase libxml2 package
Group: Development/Tools
License: MIT
Url: https://download.gnome.org/sources/libxslt/1.1/

%define _prefix /usr/local
%define _libxml2_prefix /usr/local/oceanbase/deps/devel
%define _src libxslt-%{version}
%define __arch_install_post %{nil}
%define __strip /bin/true
%define __os_install_post %{nil}
%define debug_package %{nil}

%description
Static libxslt and libexslt libraries for OceanBase. This package is built
against the libxml2 RPM supplied by devdeps-libxslt-static-build.sh.

%install
test -n "$LIBXML2_PREFIX"
test -x "$LIBXML2_PREFIX/bin/xml2-config"
test -f "$LIBXML2_PREFIX/include/libxml2/libxml/xmlversion.h"
test -f "$LIBXML2_PREFIX/lib/libxml2.a"
grep -Eq '^#define LIBXML_VERSION 21503$' \
  "$LIBXML2_PREFIX/include/libxml2/libxml/xmlversion.h"

cd $OLDPWD/../
rm -rf %{_src}
tar xf %{_src}.tar.xz
cd %{_src}

export XML_CONFIG="$LIBXML2_PREFIX/bin/xml2-config"
export LIBXML_CFLAGS="$("$XML_CONFIG" --prefix="$LIBXML2_PREFIX" --cflags)"
export LIBXML_LIBS="$("$XML_CONFIG" --prefix="$LIBXML2_PREFIX" --libs)"
export CFLAGS="${CFLAGS:--O2} -fPIC"

./configure \
  --prefix=%{_prefix} \
  --with-libxml-prefix="$LIBXML2_PREFIX" \
  --with-pic \
  --without-python \
  --without-crypto \
  --disable-shared \
  --enable-static

# This static-devel RPM intentionally contains only libxslt/libexslt headers
# and libraries. Build those deliverables directly: the unshipped xsltproc
# 1.1.34 CLI assigns to xmlParserMaxDepth, which is read-only in libxml2 2.15.
make -C libxslt %{_smp_mflags}
make -C libexslt %{_smp_mflags}
make xsltConf.sh

if nm -u libxslt/.libs/libxslt.a libexslt/.libs/libexslt.a \
    | awk '{print $NF}' \
    | grep -Eq '^(inputPush|valuePop|valuePush)$'; then
  echo "libxslt still references a pre-libxml2-2.15 ABI symbol" >&2
  exit 1
fi

make -C libxslt DESTDIR=$RPM_BUILD_ROOT install
make -C libexslt DESTDIR=$RPM_BUILD_ROOT install
rm -rf "$RPM_BUILD_ROOT/%{_prefix}/share"
install -d "$RPM_BUILD_ROOT/%{_prefix}/lib/pkgconfig"
install -d "$RPM_BUILD_ROOT/%{_prefix}/lib/libxslt-plugins"
install -m 0644 libxslt.pc "$RPM_BUILD_ROOT/%{_prefix}/lib/pkgconfig/libxslt.pc"
install -m 0644 libexslt.pc "$RPM_BUILD_ROOT/%{_prefix}/lib/pkgconfig/libexslt.pc"
install -m 0644 xsltConf.sh "$RPM_BUILD_ROOT/%{_prefix}/lib/xsltConf.sh"

for metadata in \
    "$RPM_BUILD_ROOT/%{_prefix}/lib/libxslt.la" \
    "$RPM_BUILD_ROOT/%{_prefix}/lib/libexslt.la" \
    "$RPM_BUILD_ROOT/%{_prefix}/lib/pkgconfig/libxslt.pc" \
    "$RPM_BUILD_ROOT/%{_prefix}/lib/pkgconfig/libexslt.pc" \
    "$RPM_BUILD_ROOT/%{_prefix}/lib/xsltConf.sh"; do
  sed -i "s|$LIBXML2_PREFIX|%{_libxml2_prefix}|g" "$metadata"
  if grep -F "$LIBXML2_PREFIX" "$metadata"; then
    echo "Temporary libxml2 build path remains in $metadata" >&2
    exit 1
  fi
done

%files
%defattr(-,root,root)
%{_prefix}/include/libxslt
%{_prefix}/include/libexslt
%{_prefix}/lib/libxslt.a
%{_prefix}/lib/libxslt.la
%{_prefix}/lib/libexslt.a
%{_prefix}/lib/libexslt.la
%dir %{_prefix}/lib/libxslt-plugins
%{_prefix}/lib/pkgconfig/libxslt.pc
%{_prefix}/lib/pkgconfig/libexslt.pc
%{_prefix}/lib/xsltConf.sh

%changelog
* Wed Jul 29 2026 zongmei.zzm
- rebuild libxslt 1.1.34 against libxml2 2.15.3
- build optimized static objects as PIC for the OceanBase observer link
- normalize generated metadata to the packaged libxml2 prefix
