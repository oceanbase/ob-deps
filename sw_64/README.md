# set rpm macros
%dist,  %_arch is empty in sw_64(uos20)

```
$ vim ~/.rpmmacros
```

input the following context

```
%dist .uos20
%_arch sw_64

check whether it is effective:

```
$ rpm --eval "%{dist}"
.uos20
$ rpm --eval "%{_arch}"
sw_64
```

# build all
```
bash obdevtools-cmake-build.sh
bash devdeps-openssl-static-build.sh
bash devdeps-isa-l-static-build.sh
bash devdeps-mariadb-connector-c-build.sh
bash devdeps-libunwind-static-build.sh
bash devdeps-libcurl-static-build.sh
bash devdeps-libaio-build.sh
bash devdeps-rapidjson-build.sh
bash obdevtools-ccache-build.sh
bash devdeps-rocksdb-build.sh
bash obdevtools-flex-build.sh
bash devdeps-gtest-build.sh
bash obdevtools-bison-build.sh
```
