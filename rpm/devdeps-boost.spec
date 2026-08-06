##############################################################
# http://baike.corp.taobao.com/index.php/%E6%B7%98%E5%AE%9Drpm%E6%89%93%E5%8C%85%E8%A7%84%E8%8C%83 #
# http://www.rpm.org/max-rpm/ch-rpm-inside.html              #
##############################################################
Name: devdeps-boost
Version: %(echo $VERSION)
Release: %(echo $RELEASE)%{?dist}
# if you want use the parameter of rpm_create on build time,
# uncomment below
Summary: boost for oceanbase
Group: alibaba/application
License: Boost Software License
Url: https://archives.boost.io/release/
%undefine _missing_build_ids_terminate_build
%define _build_id_links compat
%define _prefix /usr/local/oceanbase/deps/devel
%define _src %(echo $BOOST_SOURCE_DIR)
%define _src_archive %(echo $SOURCE_ARCHIVE)

%description
The Boost C++ Libraries are a collection of modern libraries based on the C++ standard.

%define debug_package %{nil}
# support debuginfo package, to reduce runtime package size

# prepare your files
%install
# OLDPWD is the dir of rpm_create running
# _prefix is an inner var of rpmbuild,
# can set by rpm_create, default is "/home/a"
# _lib is an inner var, maybe "lib" or "lib64" depend on OS

# create dirs
mkdir -p $RPM_BUILD_ROOT/%{_prefix}
cd $OLDPWD/../; 
tar xf %{_src_archive}
cd %{_src}
source_dir=$(pwd)
mkdir -p ${source_dir}/tmp_install
export PATH=$TOOLS_DIR/bin:$PATH;
export LD_LIBRARY_PATH=$TOOLS_DIR/lib:$TOOLS_DIR/lib64:$LD_LIBRARY_PATH
./bootstrap.sh --prefix=${RPM_BUILD_ROOT}/%{_prefix} --with-libraries=thread
./b2 cxxflags=-fPIC cflags=-fPIC -a stage --stagedir=${source_dir}/tmp_install variant=release threading=multi link=static
mkdir -p ${RPM_BUILD_ROOT}/%{_prefix}/lib
cp -r ${source_dir}/tmp_install/lib/*.a ${RPM_BUILD_ROOT}/%{_prefix}/lib

# install geometry files
./b2 tools/bcp
mkdir -p ${RPM_BUILD_ROOT}/%{_prefix}/include
./dist/bin/bcp boost/geometry.hpp boost/geometry.hpp boost/geometry \
boost/spirit/include/qi.hpp boost/spirit/include/phoenix.hpp boost/bind/bind.hpp boost/fusion/include/adapt_struct.hpp \
boost/lambda/lambda.hpp boost/sort ${RPM_BUILD_ROOT}/%{_prefix}/include
cd ${RPM_BUILD_ROOT}/%{_prefix}/include
# delete unnecessary files
rm -rf Jamroot
rm -rf libs


# package infomation
%files 
# set file attribute here
%defattr(-,root,root)
# need not list every file here, keep it as this
%{_prefix}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Wed Aug 05 2026 zongmei.zzm
- upgrade to 1.92.0.beta1 to pick up b2 >= 5.5.0 fix for startup crash on loongarch64 (bfgroup/b2#534)
* Tue Aug 04 2026 zongmei.zzm
- upgrade to 1.91.0
* Wed Jul 29 2026 zongmei.zzm
- upgrade to 1.81.0
* Tue Mar 10 2022 xuhao.yf
- upgrade to 1.74.0
* Fri Feb 14 2020 yuanqi.xhf
- add spec of ob-boost
