# 🚀 k230-builder

Docker build environment for K230 Linux & RTOS SDKs — one image, four toolchains.

---

## 使用

### 安装

国内用户（推荐）：
```bash
curl -fsSL https://www.kendryte.com/misc/install.sh | bash
```

GitHub（备选）：
```bash
curl -fsSL https://raw.githubusercontent.com/huangzhenming/k230-builder/main/install.sh | bash
```

安装后执行 `source ~/.bashrc` 使 PATH 生效。如需卸载：
```bash
curl -fsSL https://www.kendryte.com/misc/install.sh | bash -s -- --uninstall
```

### 编译 SDK

```bash
cd your-k230-sdk/
k230 make CONF=k230_canmv_defconfig
```

`k230` 自动处理镜像拉取、工具链下载、用户映射。默认不下载 TC4（ILP32），如需启用：
```bash
ENABLE_TC4=1 k230 make CONF=k230_evb_defconfig
```

### 镜像选择

| 网络环境 | 行为 |
|---------|------|
| 全球 | 从 `ghcr.io/huangzhenming/k230-builder` 拉取 |
| 中国 | ghcr 不可达时自动切换 `registry.kendryte.com/k230-builder` |

手动指定版本：
```bash
K230_BUILDER_TAG=dev k230 make
K230_BUILDER_TAG=v1.0.0 k230 bash
```

### 常用命令

```bash
k230 bash                      # 进入容器交互 shell
k230 make                      # 透传任意命令到容器
k230 pull                      # 手动拉取最新镜像
k230 pull dev                  # 拉取指定版本
```

容器内：
```bash
k230 env                       # 查看工具链状态
k230 setup tc2                 # 单独下载某套工具链
k230 linux / k230 rtos         # 切换 SDK 环境
```

### Git 与 SSH

`k230` 自动挂载宿主机的 `~/.ssh` 和 `~/.gitconfig`，容器内可直接 `git clone` / `repo sync`。

如宿主机有 git 对象缓存：
```bash
export K230_GIT_MIRROR=/data/git-mirror/repos
k230 bash
repo sync --reference=/data/git-mirror/repos
```

### 工具链

| ID | 名称 | 用途 |
|----|------|------|
| TC1 | Xuantie-900 5.10.4 (glibc) | RTOS U-Boot, OpenSBI |
| TC2 | Xuantie-900 6.6.0 (glibc) | Linux SDK 全组件 |
| TC3 | Musl RT-Smart | RTOS RT-Smart, MPP, CanMV |
| TC4 | RuyiSDK ILP32 (elf) | Linux ILP32 内核 |

工具链存放在 Docker Volume `k230_toolchains` 中，只下载一次。首次启动 ~10GB 磁盘，下载耗时取决于网络。

---

## 开发

### 构建

```bash
./build.sh              # git-count + short hash 版本号
./build.sh --no-cache   # 强制完整重建
```

### 项目结构

```
├── k230                 # 宿主端 wrapper 脚本
├── build.sh             # 本地构建脚本
├── docker/Dockerfile    # 镜像定义
├── scripts/
│   ├── entrypoint.sh    # 容器入口（用户创建、SSH、工具链）
│   ├── toolchain.sh     # 工具链下载/校验/安装
│   ├── k230             # 容器内 CLI
│   └── env.sh           # 环境变量导出
└── .github/workflows/   # CI：tag push → GHCR + Release
```

### CI/CD

推送 `v*` tag 触发自动构建并发布 GitHub Release：
```bash
git tag v1.0.0 && git push origin v1.0.0
```

---

## License

MIT
