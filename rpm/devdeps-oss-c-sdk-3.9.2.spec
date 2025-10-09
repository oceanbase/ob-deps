##############################################################
# http://baike.corp.taobao.com/index.php/%E6%B7%98%E5%AE%9Drpm%E6%89%93%E5%8C%85%E8%A7%84%E8%8C%83 #
# http://www.rpm.org/max-rpm/ch-rpm-inside.html              #
##############################################################
Name: devdeps-oss-c-sdk
Version: %(echo $VERSION)
Release: %(echo $RELEASE)%{?dist}
# if you want use the parameter of rpm_create on build time,
# uncomment below
Summary: aliyun oss c sdk for oceanbase
Group: Development/Tools
License: Commercial
Url: https://github.com/yasm/yasm
%define _build_id_links none
%define _prefix /usr/local/oceanbase/deps/devel
%define _src aliyun-oss-c-sdk-%{version}
%define __arch_install_post %{nil}
%define __strip /bin/true
%define __os_install_post %{nil}
%define debug_package %{nil}

# uncomment below, if your building depend on other packages

#BuildRequires: package_name = 1.0.0

# uncomment below, if depend on other packages

#Requires: package_name = 1.0.0


%description
# if you want publish current svn URL or Revision use these macros
Complete rewrite of the NASM assembler
CodeUrl:%{_source_path}
CodeRev:%{_source_revision}

%debug_package
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
rm -rf %{_src}
tar xf %{_src}.tar.gz
cd %{_src}
source_dir=$(pwd)

# replace path 
sed -i 's?/usr/bin /usr/local/bin /usr/local/apr/bin/?/usr/local/oceanbase/deps/devel/bin?g' ${source_dir}/CMakeLists.txt
sed -i 's?FIND_PROGRAM(CURL_CONFIG_BIN NAMES curl-config)?FIND_PROGRAM(CURL_CONFIG_BIN NAMES curl-config PATHS /usr/local/oceanbase/deps/devel/bin)?g' ${source_dir}/CMakeLists.txt
sed -i 's/add_subdirectory(oss_c_sdk_test)/#add_subdirectory(oss_c_sdk_test)/g' ${source_dir}/CMakeLists.txt
sed -i 's/add_subdirectory(oss_c_sdk_sample)/#add_subdirectory(oss_c_sdk_sample)/g' ${source_dir}/CMakeLists.txt
sed -i '115a include_directories("/usr/local/oceanbase/deps/devel/include/mxml")' ${source_dir}/CMakeLists.txt

DEP_DIR=/usr/local/oceanbase/deps/devel
export C_INCLUDE_PATH=$DEP_DIR/include/apr-1:$DEP_DIR/usr/include/mxml:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=$DEP_DIR/include/apr-1:$DEP_DIR/usr/include/mxml:$CPLUS_INCLUDE_PATH
ls /usr/local/oceanbase/deps/devel
ls /usr/local/oceanbase/deps/devel/bin
ls /usr/local/oceanbase/deps/devel/include
cmake -DCMAKE_INSTALL_PREFIX=${RPM_BUILD_ROOT}/%{_prefix} -G 'Unix Makefiles' .
make %{_smp_mflags}; 
make install;


# create a crontab of the package
#echo "
#* * * * * root /home/a/bin/every_min
#3 * * * * ads /home/a/bin/every_hour
#" > %{_crontab}

# package infomation
%files 
# set file attribute here
%defattr(-,root,root)
# need not list every file here, keep it as this
%{_prefix}
## create an empy dir

# %dir %{_prefix}/var/log

## need bakup old config file, so indicate here

# %config %{_prefix}/etc/sample.conf

## or need keep old config file, so indicate with "noreplace"

# %config(noreplace) %{_prefix}/etc/sample.conf

## indicate the dir for crontab

# %attr(644,root,root) %{_crondir}/*

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Tue Sep 6 2022 wenxignsen.wxs
- rename ob-oss-c-sdk to devdeps-oss-c-sdk for ob 4.0 opensource
* Fri Feb 14 2020 yuanqi.xhf
- add spec of yasm
