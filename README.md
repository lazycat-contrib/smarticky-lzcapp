# Smarticky LazyCat App

Smarticky 是一个基于 Go 的现代笔记工作台，支持 Smartisan 风格界面、Markdown 编辑和 Evernote ENEX 导入。

## 打包方式

本仓库使用 GitHub Actions 构建 LazyCat LPK，不需要在本地推送 Docker 镜像。workflow 会 checkout `dockers-x/smarticky`，通过 `lzc-cli` 构建 `embed:smarticky` 内嵌镜像，并上传 LPK artifact。

CI 只能构建远端已经存在的 Smarticky ref；要打入最新功能，请先把应用仓库提交推到 `dockers-x/smarticky`，再在 `smarticky_ref` 中填写分支名、tag 或 commit。

手动打包：

1. 打开 GitHub Actions 中的 `Build Smarticky LPK`。
2. 运行 `workflow_dispatch`，按需填写 `smarticky_ref`。
3. 下载产物 `smarticky-lpk-0.2.0`。

## 本地验证

如果需要本地构建，请让 Smarticky 源码位于本仓库同级目录，或通过 `SMARTICKY_CONTEXT` 指向源码目录：

```bash
cd smarticky-lzcapp
lzc-cli project build -o community.lazycat.czyt.smarticky-v0.2.0.lpk
lzc-cli lpk info community.lazycat.czyt.smarticky-v0.2.0.lpk
```

数据目录挂载到 `/data`，LazyCat 持久化路径为 `/lzcapp/var/data`。
