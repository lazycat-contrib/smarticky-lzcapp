# Smarticky LazyCat App

Smarticky 是一个基于 Go 的现代笔记工作台，支持 Smartisan 风格界面、Markdown 编辑和 Evernote ENEX 导入。

## 一键更新脚本

本项目提供了一键更新脚本，用于快速更新版本、构建和发布 LPK 包。

### 基本用法

```bash
# 更新版本并构建 LPK
./scripts/update-version.sh 0.6.0

# 更新版本、构建并发布到应用商店
./scripts/update-version.sh 0.6.0 --publish

# 指定上游镜像
./scripts/update-version.sh 0.6.0 --source-image ghcr.io/dockers-x/smarticky:0.6.0

# 使用镜像模板（推荐）
./scripts/update-version.sh 0.6.0 --source-template 'ghcr.io/dockers-x/smarticky:{version}'
```

### 完整选项

| 选项 | 说明 | 示例 |
|------|------|------|
| `--source-image` | 指定上游镜像地址 | `--source-image ghcr.io/dockers-x/smarticky:0.6.0` |
| `--source-template` | 镜像模板，`{version}` 会被替换 | `--source-template 'ghcr.io/dockers-x/smarticky:{version}'` |
| `--publish` | 构建后发布到应用商店 | `--publish` |
| `--changelog` | 发布日志 | `--changelog '修复了若干 bug'` |
| `--skip-copy` | 跳过镜像复制 | `--skip-copy` |
| `--skip-build` | 只更新文件，不构建 LPK | `--skip-build` |

### 环境变量

| 变量 | 说明 |
|------|------|
| `PUBLISH=1` | 等同于 `--publish` |
| `SKIP_COPY=1` | 等同于 `--skip-copy` |
| `SKIP_BUILD=1` | 等同于 `--skip-build` |
| `SMARTICKY_CONTEXT` | Smarticky 源码目录（本地构建时使用） |

### 典型工作流

#### 1. 从注释自动推导（推荐）

脚本会自动从 `lzc-manifest.yml` 的注释中提取上游镜像：

```yaml
services:
  smarticky:
    # czyt/smarticky:v0.5.0  ← 脚本会读取这个注释
    image: registry.lazycat.cloud/czyt/czyt/smarticky:e994386cc689538a
```

只需指定版本号：

```bash
./scripts/update-version.sh 0.6.0
```

#### 2. 记录源镜像模板

首次使用时记录源镜像模板，后续只需传版本号：

```bash
# 首次使用：指定模板
./scripts/update-version.sh 0.6.0 --source-template 'ghcr.io/dockers-x/smarticky:{version}'

# 后续更新：只需版本号
./scripts/update-version.sh 0.6.1
```

#### 3. 本地验证后发布

```bash
# 先构建验证
./scripts/update-version.sh 0.6.0 --skip-copy --source-image ghcr.io/dockers-x/smarticky:0.6.0

# 验证无误后发布
./scripts/update-version.sh 0.6.0 --publish
```

#### 4. 只更新文件不构建

```bash
./scripts/update-version.sh 0.6.0 --skip-build
```

## 打包方式

### GitHub Actions（推荐）

本仓库使用 GitHub Actions 构建 LazyCat LPK，不需要在本地推送 Docker 镜像。workflow 会 checkout `dockers-x/smarticky`，通过 `lzc-cli` 构建 `embed:smarticky` 内嵌镜像，并上传 LPK artifact。

CI 只能构建远端已经存在的 Smarticky ref；要打入最新功能，请先把应用仓库提交推到 `dockers-x/smarticky`，再在 `smarticky_ref` 中填写分支名、tag 或 commit。

手动打包：

1. 打开 GitHub Actions 中的 `Build Smarticky LPK`。
2. 运行 `workflow_dispatch`，按需填写 `smarticky_ref`。
3. 下载产物 `smarticky-lpk-0.2.0`。

### 本地构建

如果需要本地构建，请让 Smarticky 源码位于本仓库同级目录，或通过 `SMARTICKY_CONTEXT` 指向源码目录：

```bash
cd smarticky-lzcapp
lzc-cli project build -o community.lazycat.czyt.smarticky-v0.2.0.lpk
lzc-cli lpk info community.lazycat.czyt.smarticky-v0.2.0.lpk
```

数据目录挂载到 `/data`，LazyCat 持久化路径为 `/lzcapp/var/data`。

## 配置文件说明

| 文件 | 说明 |
|------|------|
| `package.yml` | 包元数据（版本、名称、权限等） |
| `lzc-manifest.yml` | 运行配置（服务、路由、注入等） |
| `lzc-build.yml` | 构建配置（镜像、内容目录等） |
| `lzc-deploy-params.yml` | 部署参数（用户可配置项） |

## 项目结构

```
smarticky-lzcapp/
├── scripts/
│   └── update-version.sh     # 一键更新脚本
├── content/                  # 静态内容目录
├── resources/
│   └── mcp-providers/        # MCP 资源导出
├── docs/                     # 文档
├── package.yml               # 包元数据
├── lzc-manifest.yml          # 运行配置
├── lzc-build.yml             # 构建配置
├── lzc-deploy-params.yml     # 部署参数
├── icon.png                  # 应用图标
└── README.md                 # 本文件
```

## 版本历史

| 版本 | 说明 |
|------|------|
| v0.5.0 | 当前版本，支持 MCP 资源导出 |
| v0.4.0 | 添加应用间访问权限 |
| v0.3.4 | 修复若干问题 |
| v0.3.3 | 优化构建流程 |
| v0.1.6 | 早期版本 |
| v0.1.3 | 初始发布 |

## 相关链接

- **Smarticky 源码**: https://github.com/dockers-x/smarticky
- **LazyCat 开发文档**: https://developer.lazycat.cloud
- **LazyCat 应用商店**: https://gitee.com/lazycatcloud/appdb
