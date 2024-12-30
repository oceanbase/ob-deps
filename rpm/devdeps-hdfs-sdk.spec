Name: devdeps-hdfs-sdk
Version: 3.3.6
Release: %(echo $RELEASE)%{?dist}
Summary: This is the repository for accessing files on hdfs store 
License: https://github.com/apache/hadoop/blob/trunk/LICENSE.txt
AutoReqProv:no
%undefine _missing_build_ids_terminate_build
%define _build_id_links compat
# disable check-buildroot
%define __arch_install_post %{nil}
# support debuginfo package, to reduce runtime package size
%define debug_package %{nil}

%define _prefix /usr/local/oceanbase/deps/devel
%define _cmake_src cmake
%define _OpenJDK8U_src OpenJDK8U-jdk
%define _apache_maven_src apache-maven
%define _protobuf_src protobuf
%define _texinfo_src texinfo
%define _gsasl_src gsasl
%define _src_path hadoop-rel-release-3.3.6
%define _src apache-hadoop-3.3.6
%define _product_prefix hdfs

# prepare env variables for compiling hdfspp 
%define _compiled_prefix hadoop-hdfs-project/hadoop-hdfs-native-client
%define _compiled_libs %_compiled_prefix/target/native/target/usr/local/lib
%define _header_files %_compiled_prefix/src/main/native/libhdfs/include/hdfs

%description
This is the repository for accessing files on hdfs store 

%install
# create dirs
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/lib
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}
CPU_CORES=`grep -c ^processor /proc/cpuinfo`
ROOT_DIR=$OLDPWD/..

# install cmake
cd $ROOT_DIR
rm -rf %{_cmake_src}
mkdir -p %{_cmake_src}
tar zxf %{_cmake_src}.tar.gz --strip-components=1 -C %{_cmake_src}
cd %{_cmake_src}
./bootstrap --prefix=$ROOT_DIR/%{_cmake_src} -- -DCMAKE_USE_OPENSSL=ON
make -j${CPU_CORES}
make install

# install jdk
arch=`uname -p`
cd $ROOT_DIR
rm -rf %{_OpenJDK8U_src}
mkdir -p %{_OpenJDK8U_src}
tar zxf %{_OpenJDK8U_src}-$arch.tar.gz --strip-components 1 -C %{_OpenJDK8U_src}

# install maven
rm -rf %{_apache_maven_src}
mkdir -p %{_apache_maven_src}
tar zxf %{_apache_maven_src}.tar.gz --strip-components 1 -C %{_apache_maven_src}
cp -rf patch/settings.xml %{_apache_maven_src}/conf

# install protobuf
rm -rf %{_protobuf_src}
mkdir -p %{_protobuf_src}
tar zxf %{_protobuf_src}.tar.gz --strip-components 1 -C %{_protobuf_src}
cd %{_protobuf_src}
./autogen.sh
./configure --prefix=$ROOT_DIR/%{_protobuf_src} CFLAGS="-g -O2 -fPIC" CXXFLAGS="-g -O2 -fPIC"
make -j${CPU_CORES}
make install

# install texinfo
cd $ROOT_DIR
rm -rf %{_texinfo_src}
mkdir -p %{_texinfo_src}
tar zxf %{_texinfo_src}.tar.gz --strip-components 1 -C %{_texinfo_src}
cd %{_texinfo_src}
./configure --prefix=$ROOT_DIR/%{_texinfo_src}
make -j${CPU_CORES}
make install

# install gsasl
cd $ROOT_DIR
rm -rf %{_gsasl_src}
mkdir -p %{_gsasl_src}
tar zxf %{_gsasl_src}.tar.gz --strip-components 1 -C %{_gsasl_src}
cd %{_gsasl_src}
./configure --prefix=$ROOT_DIR/%{_gsasl_src} CFLAGS="-g -O2 -fPIC" CXXFLAGS="-g -O2 -fPIC"
make -j${CPU_CORES}
make install

cd $ROOT_DIR

# compile and install `hdfspp`, note: use gcc and g++ as same as the compiler of observer
export JAVA_HOME=$ROOT_DIR/%{_OpenJDK8U_src}
export PROTOBUF_HOME=$ROOT_DIR/%{_protobuf_src}
export GSASL_HOME=$ROOT_DIR/%{_gsasl_src}
export TEXINFO_HOME=$ROOT_DIR/%{_texinfo_src}
export MAVEN_HOME=$ROOT_DIR/%{_apache_maven_src}
export PATH=$GSASL_HOME/bin:$TEXINFO_HOME/bin:$JAVA_HOME/bin:$MAVEN_HOME/bin:$ROOT_DIR/%{_cmake_src}/bin:$PROTOBUF_HOME/bin:$PATH;

rm -rf %{_src_path}
tar xf %{_src}.tar.gz
cd %{_src_path}
git init
git apply --whitespace=fix ../patch/hdfs.patch

mvn -pl :hadoop-hdfs-native-client -Pnative compile -Dnative_make_args="copy_hadoop_files"

## install protobuf
# echo "Copy libprotobuf.a from ${PROTOBUF_HOME}/lib/libprotobuf.a to $RPM_BUILD_ROOT/%{_prefix}/lib/"
# cp ${PROTOBUF_HOME}/lib/libprotobuf.a $RPM_BUILD_ROOT/%{_prefix}/lib/
## install gsasl
# echo "Copy libgsasl.a from ${GSASL_HOME}/lib/libgsasl.a to $RPM_BUILD_ROOT/%{_prefix}/lib/"
# cp ${GSASL_HOME}/lib/libgsasl.a $RPM_BUILD_ROOT/%{_prefix}/lib/
## install hdfspp
cp -P %_compiled_libs/libhdfs.so* $RPM_BUILD_ROOT/%{_prefix}/lib/
mkdir -p $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}
cp -r %_header_files/* $RPM_BUILD_ROOT/%{_prefix}/include/%{_product_prefix}/

# install mocked libjvm.so
# cp $LIBMOCKJVM $RPM_BUILD_ROOT/%{_prefix}/lib/libjvm.so

## copy jni header files
cp $ROOT_DIR/%{_OpenJDK8U_src}/include/jni.h $RPM_BUILD_ROOT/%{_prefix}/include/
cp $ROOT_DIR/%{_OpenJDK8U_src}/include/linux/* $RPM_BUILD_ROOT/%{_prefix}/include/

%files 

%defattr(-,root,root)

%{_prefix}
%exclude %dir %{_prefix}
%exclude %dir %{_prefix}/include
%exclude %dir %{_prefix}/lib

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%changelog
* Thu Nov 21 2024 huaixin.lmy
- version 3.3.6
