# 🚀 k230-builder

**K230 开发环境一键容器化解决方案**

`k230-builder` 提供完整的 K230 SDK（Linux / RTOS）编译环境，通过 Docker 实现**零依赖、开箱即用、跨平台一致性开发体验**。

---

## ✨ 特性

* 🐳 基于 Docker 的统一开发环境
* ⚙️ 支持 K230 **Linux SDK** 和 **RTOS SDK** 的 4 套交叉编译工具链
* 📦 **按需下载 Toolchain**，首次启动自动拉取
* 💾 使用 Docker Volume 持久化 Toolchain（只下载一次）
* 🚀 支持 GitHub Container Registry 自动构建与发布
* 🧩 单一镜像，环境变量控制
* 🛠 内置 `k230` CLI 工具，简化开发流程

---

## 🔧 支持的工具链

| ID | 简称 | Prefix | 用途 |
|----|------|--------|------|
| TC1 | xuantie-5.10.4 | `riscv64-unknown-linux-gnu-` | RTOS SDK: U-Boot, OpenSBI |
| TC2 | xuantie-6.6.0 | `riscv64-unknown-linux-gnu-` | Linux SDK: 主工具链（全部组件） |
| TC3 | musl | `riscv64-unknown-linux-musl-` | RTOS SDK: RT-Smart 内核, MPP, CanMV |
| TC4 | ilp32 | `riscv64-unknown-elf-` | Linux SDK: ILP32 内核编译 |

> 详细设计见 `docs/design.md`

---

## 🚀 快速开始

### 1️⃣ 运行容器

```bash
# 默认（全部 4 套工具链按需下载）
docker run -it \
  -e HOST_UID=$(id -u) \
  -e HOST_GID=$(id -g) \
  -v k230_toolchains:/opt/toolchains \
  -v $(pwd):/workspace \
  -w /workspace \
  ghcr.io/huangzhenming/k230-builder:latest

# 仅 Linux SDK
docker run -it \
  -e ENABLE_TC1=0 -e ENABLE_TC3=0 -e ENABLE_TC4=0 \
  -v k230_toolchains:/opt/toolchains \
  ghcr.io/huangzhenming/k230-builder:latest

# 仅 RTOS SDK
docker run -it \
  -e ENABLE_TC2=0 -e ENABLE_TC4=0 \
  -v k230_toolchains:/opt/toolchains \
  ghcr.io/huangzhenming/k230-builder:latest

# 自定义下载源
docker run -it \
  -e TC1_URLS="https://mirror/tc1.tar.bz2 https://mirror2/tc1.tar.bz2" \
  -v k230_toolchains:/opt/toolchains \
  ghcr.io/huangzhenming/k230-builder:latest
```

---

### 2️⃣ CLI 进入容器后

```bash
# 查看已安装的工具链状态
k230 env

# 手动触发下载（根据 ENABLE_* 环境变量）
k230 setup

# 下载指定工具链
k230 setup tc2

# 进入 Linux SDK 环境
k230 linux

# 进入 RTOS SDK 环境
k230 rtos
```

---

## 🧠 工作原理

```text
容器启动
    ↓
遍历 ENABLE_TC1~4
    ↓
已安装（.version + .installed 匹配） → 跳过
未安装 → 自动下载并解压到 /opt/toolchains/
    ↓
设置 PATH
    ↓
切换到用户，执行 CMD
```

---

## 📁 目录结构

```text
/opt/toolchains/
    ├── Xuantie-900-gcc-linux-5.10.4-glibc-x86_64-V2.6.0/   ← TC1
    ├── Xuantie-900-gcc-linux-6.6.0-glibc-x86_64-V3.0.2/    ← TC2
    ├── riscv64-linux-musleabi_for_x86_64-pc-linux-gnu/      ← TC3
    └── riscv64ilp32-elf-ubuntu-22.04-gcc-nightly-2024.06.25/ ← TC4

/opt/toolchain → /opt/toolchains  (symlink, 兼容 SDK 硬编码路径)
```

---

## 🛠 CLI 使用说明

```bash
k230 setup              # 下载所有启用的工具链
k230 setup tc1          # 只下载 TC1
k230 setup tc2          # 只下载 TC2
k230 setup tc3          # 只下载 TC3
k230 setup tc4          # 只下载 TC4
k230 setup all          # 下载全部 4 套

k230 linux              # 进入 Linux SDK 环境 (TC2)
k230 rtos               # 进入 RTOS SDK 环境 (TC1+TC3)
k230 env                # 查看工具链安装状态
```

---

## 🔧 环境变量

| 变量 | 默认 | 说明 |
|------|------|------|
| `ENABLE_TC1` | `1` | 启用 xuantie-5.10.4 |
| `ENABLE_TC2` | `1` | 启用 xuantie-6.6.0 |
| `ENABLE_TC3` | `1` | 启用 musl |
| `ENABLE_TC4` | `1` | 启用 ilp32 |
| `TC1_URLS` | — | TC1 下载源（空格分隔多源） |
| `TC2_URLS` | — | TC2 下载源 |
| `TC3_URLS` | — | TC3 下载源 |
| `TC4_URLS` | — | TC4 下载源 |
| `K230_TOOLCHAIN_ROOT` | `/opt/toolchains` | 工具链根目录 |
| `SDK_TOOLCHAIN_DIR` | `/opt/toolchain` | RTOS SDK 兼容 |
| `HOST_UID` | `1000` | 宿主机用户 UID |
| `HOST_GID` | `1000` | 宿主机用户 GID |

---

## 🐳 构建镜像（开发者）

```bash
docker build -f docker/Dockerfile -t k230-builder:latest .
```

---

## 🚀 CI / 自动发布

项目使用 GitHub Actions 自动构建镜像，并发布到 GHCR：

```text
ghcr.io/<your-username>/k230-builder:latest
```

---

## 💡 设计理念

### ❌ 不推荐

* 将 toolchain 打包进镜像（体积 10GB+）
* 多个镜像变体（base/rtos/linux/full）

### ✅ 推荐

* 镜像只包含环境
* toolchain 按需下载 + 持久化
* 单一镜像 + 环境变量控制

---

## ⚠️ 注意事项

### 1️⃣ 网络问题

建议提供多源下载（CDN / OSS）：

```text
GitHub / 国内镜像 / 私有服务器
```

---

### 2️⃣ 磁盘空间

* TC1 ≈ 2GB
* TC2 ≈ 4GB
* TC3 ≈ 2GB
* TC4 ≈ 1GB

---

### 3️⃣ 首次启动较慢

👉 属于正常现象（下载 toolchain）

---

## 🤝 贡献

欢迎提交 PR / Issue！

---

## 📄 License

BSD 3-Clause License

---

## ⭐ 支持项目

如果这个项目对你有帮助，欢迎 Star ⭐
