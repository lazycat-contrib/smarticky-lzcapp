#!/usr/bin/env bash
set -euo pipefail

# Smarticky LPK 一键更新脚本
# 用法: ./scripts/update-version.sh <版本号> [选项]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

usage() {
  cat <<'USAGE'
Smarticky LPK 一键更新脚本

用法: ./scripts/update-version.sh <版本号> [选项]

示例:
  ./scripts/update-version.sh 0.6.0                    # 更新版本，构建 LPK
  ./scripts/update-version.sh 0.6.0 --publish          # 更新版本，构建并发布
  ./scripts/update-version.sh 0.6.0 --source-image ghcr.io/dockers-x/smarticky:0.6.0  # 指定源镜像

选项:
  --source-image <image>       指定上游镜像地址
  --source-template <template> 镜像模板，使用 {version} 占位，如 ghcr.io/dockers-x/smarticky:{version}
  --publish                    构建后发布到应用商店
  --changelog <text>           发布日志，默认: "更新到 <版本号>"
  --skip-copy                  跳过镜像复制，直接使用 --source-image 作为 manifest 镜像
  --skip-build                 只更新文件，不构建 LPK
  --git-push                   发布成功后自动 git 提交并推送
  -h, --help                   显示帮助

环境变量:
  PUBLISH=1          等同于 --publish
  SKIP_COPY=1        等同于 --skip-copy
  SKIP_BUILD=1       等同于 --skip-build
  GIT_PUSH=1         等同于 --git-push
  SMARTICKY_CONTEXT  Smarticky 源码目录（本地构建时使用）
USAGE
}

die() {
  echo "❌ 错误: $*" >&2
  exit 1
}

info() {
  echo "ℹ️  $*" >&2
}

success() {
  echo "✅ $*" >&2
}

warn() {
  echo "⚠️  $*" >&2
}

# 解析参数
VERSION="${1:-}"
if [[ -z "$VERSION" || "$VERSION" == "-h" || "$VERSION" == "--help" ]]; then
  usage
  [[ "$VERSION" == "-h" || "$VERSION" == "--help" ]] && exit 0
  exit 1
fi
shift

SOURCE_IMAGE="${SOURCE_IMAGE:-}"
SOURCE_TEMPLATE="${SOURCE_TEMPLATE:-}"
PUBLISH="${PUBLISH:-0}"
CHANGELOG="${CHANGELOG:-}"
SKIP_COPY="${SKIP_COPY:-0}"
SKIP_BUILD="${SKIP_BUILD:-0}"
GIT_PUSH="${GIT_PUSH:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-image) SOURCE_IMAGE="${2:-}"; shift 2 ;;
    --source-template) SOURCE_TEMPLATE="${2:-}"; shift 2 ;;
    --publish) PUBLISH=1; shift ;;
    --changelog) CHANGELOG="${2:-}"; shift 2 ;;
    --skip-copy) SKIP_COPY=1; shift ;;
    --skip-build) SKIP_BUILD=1; shift ;;
    --git-push) GIT_PUSH=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "未知选项: $1" ;;
  esac
done

# 检查必要文件
[[ -f "$PROJECT_DIR/package.yml" ]] || die "未找到 package.yml"
[[ -f "$PROJECT_DIR/lzc-manifest.yml" ]] || die "未找到 lzc-manifest.yml"
[[ -f "$PROJECT_DIR/lzc-build.yml" ]] || die "未找到 lzc-build.yml"

# 检查命令
command -v awk >/dev/null 2>&1 || die "需要 awk 命令"
command -v sed >/dev/null 2>&1 || die "需要 sed 命令"

# 获取当前版本
CURRENT_VERSION=$(awk '/^version:/ { print $2; exit }' "$PROJECT_DIR/package.yml")
info "当前版本: $CURRENT_VERSION"
info "目标版本: $VERSION"

# 获取包名
PACKAGE_ID=$(awk '/^package:/ { print $2; exit }' "$PROJECT_DIR/package.yml")
PACKAGE_ID="${PACKAGE_ID//\"/}"
info "包名: $PACKAGE_ID"

# 获取当前镜像和注释中的上游镜像
CURRENT_IMAGE=$(awk '/^    image:/ { print $2; exit }' "$PROJECT_DIR/lzc-manifest.yml")
COMMENT_IMAGE=$(grep -E '^\s+#\s+\S+/\S+:' "$PROJECT_DIR/lzc-manifest.yml" | head -1 | sed 's/.*#\s*//' | sed 's/[[:space:]]*$//')
info "当前镜像: $CURRENT_IMAGE"
[[ -n "$COMMENT_IMAGE" ]] && info "注释中的上游镜像: $COMMENT_IMAGE"

# 确定源镜像
if [[ -z "$SOURCE_IMAGE" ]]; then
  if [[ -n "$SOURCE_TEMPLATE" ]]; then
    # 使用模板
    SOURCE_IMAGE="${SOURCE_TEMPLATE//\{version\}/$VERSION}"
    SOURCE_IMAGE="${SOURCE_IMAGE//\{\{version\}\}/$VERSION}"
  elif [[ -n "$COMMENT_IMAGE" ]]; then
    # 从注释中提取上游镜像，替换版本号
    if [[ "$COMMENT_IMAGE" == *:* ]]; then
      SOURCE_IMAGE="${COMMENT_IMAGE%:*}:$VERSION"
    else
      SOURCE_IMAGE="$COMMENT_IMAGE:$VERSION"
    fi
    info "从注释推导源镜像: $SOURCE_IMAGE"
  else
    # 从当前镜像推导
    if [[ "$CURRENT_IMAGE" == registry.lazycat.cloud/* ]]; then
      die "当前镜像已在 LazyCat 仓库，请使用 --source-image 或 --source-template 指定上游镜像\n\n示例:\n  ./scripts/update-version.sh $VERSION --source-image ghcr.io/dockers-x/smarticky:$VERSION\n  ./scripts/update-version.sh $VERSION --source-template 'ghcr.io/dockers-x/smarticky:{version}'"
    fi
    # 尝试移除标签并添加新版本
    if [[ "$CURRENT_IMAGE" == *:* ]]; then
      SOURCE_IMAGE="${CURRENT_IMAGE%:*}:$VERSION"
    else
      SOURCE_IMAGE="$CURRENT_IMAGE:$VERSION"
    fi
  fi
fi
info "源镜像: $SOURCE_IMAGE"

# 复制镜像
LAZYCAT_IMAGE=""
if [[ "$SKIP_COPY" == "1" ]]; then
  LAZYCAT_IMAGE="$SOURCE_IMAGE"
  warn "跳过镜像复制，使用: $LAZYCAT_IMAGE"
else
  info "正在复制镜像到 LazyCat 仓库..."

  # 优先使用 fish 函数
  if command -v fish >/dev/null 2>&1 && fish -lc 'functions -q lzc-copy-image' 2>/dev/null; then
    info "使用 fish 函数: lzc-copy-image"
    if ! COPY_OUTPUT=$(COPY_IMAGE="$SOURCE_IMAGE" fish -lc 'lzc-copy-image "$COPY_IMAGE"' 2>&1); then
      echo "$COPY_OUTPUT" >&2
      die "镜像复制失败"
    fi
  elif command -v lzc-cli >/dev/null 2>&1; then
    info "使用 lzc-cli: lzc-cli appstore copy-image $SOURCE_IMAGE"
    if ! COPY_OUTPUT=$(lzc-cli appstore copy-image "$SOURCE_IMAGE" 2>&1); then
      echo "$COPY_OUTPUT" >&2
      die "镜像复制失败"
    fi
  else
    die "需要 lzc-cli 或 fish 的 lzc-copy-image 函数"
  fi

  # 解析输出中的 registry 地址
  LAZYCAT_IMAGE=$(echo "$COPY_OUTPUT" | grep -Eo 'registry\.lazycat\.cloud/[A-Za-z0-9._:@/-]+' | tail -n 1)
  [[ -n "$LAZYCAT_IMAGE" ]] || die "无法从 copy-image 输出解析镜像地址"
fi

success "镜像地址: $LAZYCAT_IMAGE"

# 更新 package.yml 版本
info "更新 package.yml 版本..."
sed -i "s/^version:.*/version: $VERSION/" "$PROJECT_DIR/package.yml"
success "package.yml 版本已更新为 $VERSION"

# 更新 lzc-manifest.yml 镜像
info "更新 lzc-manifest.yml 镜像..."
# 转义斜杠用于 sed
ESCAPED_IMAGE=$(echo "$LAZYCAT_IMAGE" | sed 's/[&/\]/\\&/g')
sed -i "s|^\(    image:\).*|\1 $LAZYCAT_IMAGE|" "$PROJECT_DIR/lzc-manifest.yml"
success "lzc-manifest.yml 镜像已更新"

# 更新注释中的版本
sed -i "s|# czyt/smarticky:v[0-9.]*|# czyt/smarticky:v$VERSION|" "$PROJECT_DIR/lzc-manifest.yml"

# 构建 LPK
LPK_FILE="$PROJECT_DIR/${PACKAGE_ID}-v${VERSION}.lpk"

if [[ "$SKIP_BUILD" == "1" ]]; then
  warn "跳过 LPK 构建"
else
  if ! command -v lzc-cli >/dev/null 2>&1; then
    warn "lzc-cli 未安装，跳过构建"
  else
    info "正在构建 LPK..."
    cd "$PROJECT_DIR"
    lzc-cli project build -o "$LPK_FILE"
    [[ -f "$LPK_FILE" ]] || die "构建失败，未生成 LPK 文件"
    success "LPK 构建完成: $LPK_FILE"
  fi
fi

# 发布
if [[ "$PUBLISH" == "1" ]]; then
  if [[ ! -f "$LPK_FILE" ]]; then
    die "LPK 文件不存在，无法发布: $LPK_FILE"
  fi

  CHANGELOG="${CHANGELOG:-更新到 $VERSION}"

  if command -v fish >/dev/null 2>&1 && fish -lc 'functions -q lzc-publish' 2>/dev/null; then
    info "使用 fish 函数发布..."
    LPK_FILE="$LPK_FILE" CHANGELOG="$CHANGELOG" LANG_CODE="zh" \
      fish -lc 'lzc-publish "$LPK_FILE" "$CHANGELOG" "$LANG_CODE"'
  elif command -v lzc-cli >/dev/null 2>&1; then
    info "使用 lzc-cli 发布..."
    lzc-cli appstore publish "$LPK_FILE" -c "$CHANGELOG" --clang zh
  else
    die "需要 lzc-cli 或 fish 的 lzc-publish 函数"
  fi

  success "发布完成!"
fi

# Git 提交并推送（仅在发布成功后）
if [[ "$GIT_PUSH" == "1" ]]; then
  if [[ "$PUBLISH" != "1" ]]; then
    warn "未发布（缺少 --publish），跳过 git 提交推送"
  else
    command -v git >/dev/null 2>&1 || die "需要 git 命令"
    cd "$PROJECT_DIR"
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "当前目录不是 git 仓库"

    info "提交并推送到 git..."
    git add -A
    if git diff --cached --quiet; then
      warn "没有需要提交的变更，跳过提交"
    else
      git commit -m "bump $VERSION"
      success "已提交: bump $VERSION"
    fi

    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    if git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
      git push
    else
      git push -u origin "$BRANCH"
    fi
    success "已推送到远程分支: $BRANCH"
  fi
fi

# 输出摘要
echo ""
echo "========================================="
echo "📦 更新摘要"
echo "========================================="
echo "包名:     $PACKAGE_ID"
echo "版本:     $CURRENT_VERSION → $VERSION"
echo "镜像:     $LAZYCAT_IMAGE"
echo "LPK 文件: $LPK_FILE"
echo "发布状态: $([ "$PUBLISH" == "1" ] && echo "已发布" || echo "未发布")"
echo "Git 推送: $([ "$GIT_PUSH" == "1" ] && [ "$PUBLISH" == "1" ] && echo "已推送" || echo "未推送")"
echo "========================================="
