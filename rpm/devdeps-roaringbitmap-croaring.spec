Name: devdeps-roaringbitmap-croaring
Version: 3.0.0
Release: %(echo $RELEASE)%{?dist}
 
Summary:  Roaring bitmaps are compressed bitmaps which tend to outperform conventional compressed bitmaps. 
 
License:  Apache License 2.0
Url: https://github.com/RoaringBitmap/CRoaring/releases/tag/v3.0.0
AutoReqProv:no
 
%undefine _missing_build_ids_terminate_build
# disable check-buildroot
%define __arch_install_post %{nil}
%define _buliddir %{_topdir}/BUILD
%define _tmppath %{_buliddir}/_tmp
%define _prefix /usr/local/oceanbase/deps/devel
%define _RoaringBitmap CRoaring-3.0.0
%define debug_package %{nil}
 
%description
Roaring bitmaps are compressed bitmaps which tend to outperform conventional compressed bitmaps. 
 
%install
mkdir -p %{buildroot}/%{_prefix}/lib/
mkdir -p %{buildroot}/%{_prefix}/include/
cd $OLDPWD/../
rm -rf %{_RoaringBitmap}
tar -zxf %{_RoaringBitmap}.tar.gz
cd %{_RoaringBitmap}
mkdir -p build
cd build
cmake .. -DCMAKE_INSTALL_PREFIX=%{_tmppath} -DCMAKE_LIBRARY_OUTPUT_DIRECTORY=%{_tmppath} -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DROARING_DISABLE_AVX512=ON -DENABLE_ROARING_TESTS=OFF -DROARING_USE_CPM=OFF
cmake --build .

cp -r ../include/roaring/ %{buildroot}/%{_prefix}/include/
cp -r ../cpp/* %{buildroot}/%{_prefix}/include/roaring/
cp src/*.a %{buildroot}/%{_prefix}/lib/
 
%files
 
%defattr(-,root,root)
 
%{_prefix}
 
%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig
 
%changelog
* Mon Mar 25 2024 oceanbase
- roaringbitmap-croaring 3.0.0

