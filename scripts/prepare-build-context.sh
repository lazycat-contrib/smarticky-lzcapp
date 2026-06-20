#!/bin/sh
set -eu

app_context="${SMARTICKY_CONTEXT:-../smarticky}"
build_context=".lzc-build/smarticky"

if [ ! -d "$app_context" ]; then
  echo "Smarticky source not found at $app_context" >&2
  echo "Set SMARTICKY_CONTEXT or place the app repository next to this packaging repository." >&2
  exit 1
fi

version="$(awk '/^version:/ { print $2; exit }' package.yml | tr -d '"')"
git_commit="$(git -C "$app_context" rev-parse --short HEAD 2>/dev/null || echo unknown)"

rm -rf .lzc-build
mkdir -p "$build_context"

if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete \
    --exclude '.git' \
    --exclude 'web/app/node_modules' \
    "$app_context"/ "$build_context"/
else
  (cd "$app_context" && tar --exclude='.git' --exclude='web/app/node_modules' -cf - .) | \
    (cd "$build_context" && tar -xf -)
fi

cp Dockerfile.smarticky "$build_context/Dockerfile.lazycat"
printf '%s\n' "$version" > "$build_context/.smarticky-version"
printf '%s\n' "$git_commit" > "$build_context/.smarticky-git-commit"
