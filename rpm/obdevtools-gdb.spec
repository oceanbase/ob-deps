Name: obdevtools-gdb
Version: %(echo $VERSION)
Release: %(echo $RELEASE)%{?dist}

Summary: The GNU Compiler Collection
Group: oceanbase-devel/tools

License: GPL

Url: https://sourceware.org/gdb/
AutoReqProv:no

# disable check-buildroot
%define __arch_install_post %{nil}

%undefine _missing_build_ids_terminate_build
%define _build_id_links compat

%define _prefix /usr/local/gdb-13
%define _gdb_src gdb-%{version}

%description
GDB, the GNU Project debugger, allows you to see what is going on `inside' another program while it executes -- or what another program was doing at the moment it crashed.

%define debug_package %{nil}

%install
cd $OLDPWD/../; 
rm -rf %{_gdb_src}
tar -xf %{_gdb_src}.tar.xz
source_dir=$(pwd)
tmp_dir=${source_dir}/install
rm -rf ${tmp_dir} && mkdir -p ${tmp_dir}
CPU_CORES=`grep -c ^processor /proc/cpuinfo`

cd ${source_dir}/%{_gdb_src}
mkdir -p build && cd build
LDFLAGS="-static-libgcc -static-libstdc++" ../configure --prefix=${tmp_dir}
make -j${CPU_CORES}
make install

mkdir -p ${RPM_BUILD_ROOT}/%{_prefix}/lib
cp -r ${tmp_dir}/bin ${RPM_BUILD_ROOT}/%{_prefix}
cp -r ${tmp_dir}/lib/*.a ${RPM_BUILD_ROOT}/%{_prefix}/lib
cp -r ${tmp_dir}/include/gdb ${RPM_BUILD_ROOT}/%{_prefix}

%files
%defattr(-,root,root)
%{_prefix}

%post
# update shard lib cache
/sbin/ldconfig

# Detect the user home directory
USER_HOME=$(getent passwd $(logname) | cut -d: -f6)
BASHRC_FILE="$USER_HOME/.bashrc"

# Add /usr/local/gdb-13/bin to PATH if it's not already added
if [ -f "$BASHRC_FILE" ]; then
    if ! grep -q "/usr/local/gdb-13/bin" "$BASHRC_FILE"; then
        cat << EOF >> "$BASHRC_FILE"
if [ -d "/usr/local/gdb-13/bin" ]; then
    export PATH=/usr/local/gdb-13/bin:\$PATH
fi
EOF
        echo "Added GDB path to $BASHRC_FILE"
    else
        echo "GDB path already exists in $BASHRC_FILE"
    fi
    echo "Please run 'source ~/.bashrc' or re-login to apply the new PATH settings."
else
    echo "$BASHRC_FILE not found, skipping PATH update."
fi

%postun
/sbin/ldconfig
# Detect the user home directory
echo "Please run 'source ~/.bashrc' or re-login to apply the new PATH settings."

%changelog
* Mon Jun 9 2025 huaixin.lmy
- gdb 13.2
