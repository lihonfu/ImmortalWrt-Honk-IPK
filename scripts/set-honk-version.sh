#!/bin/sh
# =============================================================================
# 设置 honk 包的目标版本
#
#   set-honk-version.sh <Makefile 路径> <版本> <git tag>
#
# Makefile 里版本写法是：
#   PKG_VERSION:=$(if $(HONK_VERSION),$(HONK_VERSION),0.1.0_beta6)
#   HONK_GIT_TAG:=$(if $(HONK_GIT_TAG),$(HONK_GIT_TAG),v0.1.0-beta.6)
#
# 只替换 if(...) 的最后一个参数，保留结构。默认值已经正确时不动。
# =============================================================================
set -eu

MK="$1"
VER="$2"
TAG="$3"

[ -f "$MK" ] || { echo "错误: $MK 不存在" >&2; exit 1; }

# 提取当前默认值（if(...) 里最后一段）
cur_ver=$(grep -E '^PKG_VERSION:=' "$MK" | sed 's/.*,\([^,)]*\))$/\1/')
cur_tag=$(grep -E '^HONK_GIT_TAG:=' "$MK" | sed 's/.*,\([^,)]*\))$/\1/')

echo "当前默认: PKG_VERSION=$cur_ver  HONK_GIT_TAG=$cur_tag"
echo "目标版本: $cur_ver -> $VER"
echo "目标 tag: $cur_tag -> $TAG"

changed=0

if [ "$cur_ver" != "$VER" ]; then
    # 用 awk 精确替换 PKG_VERSION 行末尾的默认值
    awk -v new="$VER" '
        /^PKG_VERSION:=/ {
            # 找到最后一个逗号，后面到 ) 之间就是默认值
            i = length($0)
            # 去掉尾部 )
            sub(/\)[[:space:]]*$/, "")
            # 找到最后一个逗号位置
            n = 0
            for (k = 1; k <= length($0); k++) {
                if (substr($0, k, 1) == ",") n = k
            }
            if (n > 0) {
                print substr($0, 1, n) new ")"
                next
            }
        }
        { print }
    ' "$MK" > "$MK.tmp" && mv "$MK.tmp" "$MK"
    echo "已更新 PKG_VERSION -> $VER"
    changed=1
fi

if [ "$cur_tag" != "$TAG" ]; then
    awk -v new="$TAG" '
        /^HONK_GIT_TAG:=/ {
            sub(/\)[[:space:]]*$/, "")
            n = 0
            for (k = 1; k <= length($0); k++) {
                if (substr($0, k, 1) == ",") n = k
            }
            if (n > 0) {
                print substr($0, 1, n) new ")"
                next
            }
        }
        { print }
    ' "$MK" > "$MK.tmp" && mv "$MK.tmp" "$MK"
    echo "已更新 HONK_GIT_TAG -> $TAG"
    changed=1
fi

if [ "$changed" = "0" ]; then
    echo "默认值已正确，无需修改"
fi

echo "修改后:"
grep -E '^PKG_VERSION:=|^HONK_GIT_TAG:=' "$MK" || true
