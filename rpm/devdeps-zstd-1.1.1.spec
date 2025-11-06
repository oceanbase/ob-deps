Name: devdeps-zstd
Version: %(echo $VERSION)
Release: %(echo $RELEASE)%{?dist}
Summary: Zstandard - fast lossless compression library and command-line tool
License: https://github.com/facebook/zstd/blob/dev/LICENSE
AutoReqProv:no

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat
# support debuginfo package, to reduce runtime package size
%define debug_package %{nil}
%define _prefix /usr/local/oceanbase/deps/devel
%define _product_prefix zstd
%define _src zstd-%{version}

%description
Zstandard - fast lossless compression library and command-line tool

%install
# create dirs
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/lib/zstd
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/include/zstd
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
export CFLAGS="-fPIC -fvisibility=hidden -Wno-implicit-fallthrough"
export CXXFLAGS="-fPIC -fvisibility=hidden -D_GLIBCXX_USE_CXX11_ABI=0 -Wno-implicit-fallthrough"
ROOT_DIR=$OLDPWD/..

# compile and install
cd $ROOT_DIR
source_dir=$(pwd)
tmp_install=${source_dir}/tmp_install
rm -rf ${tmp_install}
mkdir -p ${tmp_install}
rm -rf %{_src}
mkdir -p %{_src}
tar -xf %{_src}.tar.gz -C %{_src} --strip-components=1
cd %{_src}

## modify compress mothed
sed -i '16i#define OB_OLD_ZSTD_LIB_VERSION 1' ./lib/zstd.h
# 修改 ZSTD_compressCCtx 函数声明（第 130 行）
sed -i '130s/int compressionLevel);/int compressionLevel, int *zstd_version);/' ./lib/zstd.h
# 修改 ZSTD_compressCCtx 函数实现（第 2703 行）
sed -i '2703s/int compressionLevel)/int compressionLevel, int *zstd_version)/' ./lib/compress/zstd_compress.c
# 在函数体内添加版本检查代码（第 2705 行之后插入）
sed -i '2705i\
    if (NULL != zstd_version) {\n      *zstd_version = OB_OLD_ZSTD_LIB_VERSION;\n    }\n    //fprintf(stderr, __FILE__ ":  ytest old compress\\n");' ./lib/compress/zstd_compress.c
# 修改 ZSTD_compress 函数中对 ZSTD_compressCCtx 的调用（第 2718 行，因为前面插入了代码所以可能变成了 2722 行）
sed -i '/result = ZSTD_compressCCtx(&ctxBody, dst, dstCapacity, src, srcSize, compressionLevel);/s/compressionLevel);/compressionLevel, NULL);/' ./lib/compress/zstd_compress.c

## modify decompress mothed
# 修改 ZSTD_decompressDCtx 函数声明（第 139 行）
sed -i '139s/size_t srcSize);/size_t srcSize, int *zstd_version);/' ./lib/zstd.h
# 修改 ZSTD_decompressDCtx 函数实现（第 1181 行）
sed -i '1181s/size_t srcSize)/size_t srcSize, int *zstd_version)/' ./lib/decompress/zstd_decompress.c
# 在函数体内添加版本检查代码（第 2705 行之后插入）
sed -i '1183i\
    if (NULL != zstd_version) {\n      *zstd_version = OB_OLD_ZSTD_LIB_VERSION;\n    }\n    //fprintf(stderr, __FILE__ ":  ytest old decompress\\n");' ./lib/decompress/zstd_decompress.c
# 修改 ZSTD_decompress 函数中对 ZSTD_decompressDCtx 的调用（第 1193 行，因为前面插入了代码所以可能变成了 1197 行）
sed -i '/regenSize = ZSTD_decompressDCtx(dctx, dst, dstCapacity, src, srcSize);/s/srcSize);/srcSize, NULL);/' ./lib/decompress/zstd_decompress.c

make -j${CPU_CORES} PREFIX=${tmp_install}
make install PREFIX=${tmp_install}
 
# install files
# 复制静态库 & 头文件
cp -r ${tmp_install}/lib/libzstd.a $RPM_BUILD_ROOT/%{_prefix}/lib/zstd/ || true
cp -r ${tmp_install}/include/*.h $RPM_BUILD_ROOT/%{_prefix}/include/zstd/ || true

# package infomation
%files 
# set file attribute here
%defattr(-,root,root)
# need not list every file here, keep it as this
%{_prefix}
%exclude %dir %{_prefix}
%exclude %dir %{_prefix}/include
%exclude %dir %{_prefix}/lib64
 
%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig
 
%changelog
* Tue Oct 28 2025 huaixin.lmy
- version init