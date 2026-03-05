# ob-deps -- Android NDK Cross-Compilation

Build all SeekDB third-party dependencies as static libraries for Android arm64-v8a.

## Prerequisites

### Android NDK

**Required version**: NDK r26d (26.3.11579264)

Install via Android Studio SDK Manager, or command line:

```bash
sdkmanager "ndk;26.3.11579264"
```

The build scripts default to `$HOME/Library/Android/sdk/ndk/26.3.11579264` (standard Android Studio path on macOS). If your NDK is installed elsewhere, set:

```bash
export ANDROID_NDK_HOME=/path/to/ndk/26.3.11579264
```

### macOS Host Tools

The build runs on macOS (Apple Silicon or Intel). Required tools:

```bash
brew install cmake autoconf automake libtool pkg-config
```

Some deps (boost, libxml2, openssl) use autotools; the rest use CMake.

### Source Submodules

All dependency sources are git submodules under `sources/`. Initialize them before building:

```bash
git submodule update --init sources/*
```

## Build

```bash
bash ndk/build_all.sh
```

This builds all 20 dependencies in dependency order and produces tarballs in `ndk/output/`.

To rebuild a single dependency:

```bash
bash ndk/devdeps-openssl-build.sh
```

## Output

Tarballs in `ndk/output/` follow the naming convention `devdeps-{name}-{version}-{date}.tar.gz`. Internal layout:

```
devdeps-{name}-{version}/
  usr/local/oceanbase/deps/devel/
    lib/     # static .a files
    include/ # headers
```

## Dependencies (20 total)

| Phase | Library | Notes |
|-------|---------|-------|
| 1 | fast-float 6.1.3 | Header-only |
| 1 | relaxed-rapidjson 1.0.0 | Header-only |
| 1 | zlib 1.2.13 | |
| 1 | xz (liblzma) 5.2.2 | |
| 1 | openssl 1.1.1u | |
| 1 | icu 69.1 | |
| 1 | abseil-cpp 20211102.0 | |
| 1 | roaringbitmap 3.0.0 | |
| 1 | protobuf-c 1.4.1 | |
| 1 | mxml 2.12.0 | |
| 1 | lua 5.4.6 | |
| 1 | libxml2 2.10.4 | |
| 1 | boost 1.74.0 | system, thread, atomic + headers |
| 2 | libcurl 8.2.1 | Needs openssl |
| 2 | mariadb-connector-c 3.1.12 | Needs openssl, zlib |
| 2 | s2geometry 0.10.0 | Needs abseil-cpp |
| 3 | apache-arrow 20.0.0 | Needs zlib; bundles own snappy/lz4/zstd |
| 3 | aws-sdk-cpp 1.11.156 | Needs openssl, libcurl, zlib |
| 4 | apache-orc 1.8.8 | Needs zlib; bundles protobuf (host+target) |
| 5 | vsag 0.18.0 | Needs roaringbitmap, boost headers |
