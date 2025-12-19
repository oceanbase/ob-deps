# OceanBase Dependencies Build System For MacOS

本项目用于构建 OceanBase 数据库在MacOS上所需的开发工具和依赖库。

## 项目结构

```
ob-deps/
├── rpm/                    # 构建脚本目录
│   ├── obdevtools-*.sh    # 开发工具构建脚本
│   ├── devdeps-*-build.sh # 依赖库构建脚本
│   └── build_all.sh       # 批量构建脚本
├── patch/                  # 补丁文件目录
│   ├── fix-outline-atomics.patch  # LLVM 17.0.6 Apple Silicon 修复
│   └── ...                 # 其他补丁文件
└── cmake/                  # CMake 配置文件
```

## 支持的平台

- **macOS** (Apple Silicon / Intel)

## 开发工具 (obdevtools)

| 工具 | 版本 | 说明 |
|------|------|------|
| LLVM | 17.0.6 | 包含 Clang、LLD、Compiler-RT |
| Bison | 2.4.1 | 语法分析器生成器 |
| Flex | 2.5.35 | 词法分析器生成器 |

## 开发依赖 (devdeps)

### 核心库
- **abseil-cpp** (20211102.0) - Google C++ 基础库
- **boost** (1.74.0) - C++ 工具库
- **zlib** (1.2.13) - 压缩库
- **xz** (5.2.2) - 压缩库
- **openssl** (1.1.1u) - 加密库

### 数据处理
- **apache-arrow** (9.0.0) - 列式内存格式
- **apache-orc** (1.8.8) - ORC 文件格式
- **protobuf** (3.20.3) - 序列化库
- **protobuf-c** (1.4.1) - Protobuf C 绑定
- **rapidjson** (1.0.0) - JSON 解析库
- **fast_float** (6.1.3) - 快速浮点数解析

### 地理空间
- **s2geometry** (0.10.0) - Google S2 地理库
- **roaringbitmap-croaring** (3.0.0) - 位图库

### 网络与存储
- **libcurl** (8.12.1) - HTTP 客户端库
- **aws-sdk-cpp** (1.11.156) - AWS SDK
- **mariadb-connector-c** (3.1.12) - MariaDB 连接器

### 其他
- **icu** (69.1) - Unicode 库
- **libxml2** (2.10.4) - XML 解析库
- **lua** (5.4.6) - 脚本语言
- **mxml** (2.12.0) - XML 库

## 快速开始

### 前置要求

- **macOS**: Xcode Command Line Tools
- **Linux**: `build-essential`, `cmake`, `wget`
- 足够的磁盘空间（建议 > 10GB）

### 构建单个组件

```bash
cd rpm

bash obdevtools-flex-build.sh /xxx/ob-deps/rpm obdevtools-flex 2.5.35 20251219
```

### 批量构建所有依赖

```bash
cd rpm
./build_all.sh
```

构建产物会生成在 `rpm/` 目录下，格式为 `{package}-{version}-{release}.tar.gz`

## 构建产物

构建完成后，所有产物会打包为 `.tar.gz` 文件，包含：

```
usr/local/oceanbase/
├── devtools/          # 开发工具 (LLVM, Bison, Flex)
└── deps/
    └── devel/         # 开发依赖库
```

## 版本管理

- **RELEASE 版本号**: 格式为 `YYMMDD01`（例如：`24121901`）
- 可通过 `build_all.sh` 统一设置所有组件的 RELEASE 版本

## 许可证

各组件遵循其各自的许可证。请参考各组件源代码中的 LICENSE 文件。