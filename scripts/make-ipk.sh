#!/bin/sh
# =============================================================================
# 把 OpenWrt SDK 编译出的 honk 打包成 opkg 能装的 .ipk
#
#   make-ipk.sh <SDK目录> <输出目录>
#
# 背景：ImmortalWrt 25.12 的 SDK 生成 .apk（apk-tools 格式），
#       但目标路由器的固件是 opkg 构建的，只能装 .ipk。
#       编译完成后的安装树在 build_dir/.../.pkgdir/honk/，
#       这里用它重新打成标准 ipk（ar + control.tar.gz + data.tar.gz）。
# =============================================================================
set -eu

SDK="${1:?需要 SDK 目录}"
OUT="${2:-/tmp/out}"
mkdir -p "$OUT"

cd "$SDK"

# 1. 找安装树
PKGDIR=$(find build_dir -maxdepth 4 -type d -path '*honk*/.pkgdir/honk' 2>/dev/null | head -1)
if [ -z "$PKGDIR" ]; then
    echo "找不到 .pkgdir/honk，列出候选:" >&2
    find build_dir -maxdepth 4 -type d -name '.pkgdir' 2>/dev/null | head -10 >&2
    exit 1
fi
echo "安装树: $PKGDIR"
echo "内容:"
find "$PKGDIR" -type f -o -type l 2>/dev/null | sed 's|^|  |' | head -20

# 2. 版本号
VER=$(find build_dir -maxdepth 2 -type d -name 'honk-*' 2>/dev/null | head -1 | sed 's|.*/honk-||')
[ -z "$VER" ] && VER="0.1.0_beta6"
PKGVER="${VER}-r1"
echo "版本: $PKGVER"

# 3. 检查二进制存在且是 aarch64
BIN="$PKGDIR/usr/bin/honk-core"
if [ ! -f "$BIN" ]; then
    echo "错误: $BIN 不存在" >&2
    exit 1
fi
BINSZ=$(wc -c < "$BIN")
echo "honk-core: $BINSZ B"
if [ "$BINSZ" -lt 1000000 ]; then
    echo "警告: 二进制偏小，可能编译有问题" >&2
fi

# 4. 准备 control
CTRL="$OUT/control"
cat > "$CTRL" <<EOF
Package: honk
Version: $PKGVER
Depends: libc, libstdcpp6, kmod-veth, kmod-sched-core, kmod-sched-bpf, kmod-nft-core, kmod-nft-queue, kmod-nfnetlink-queue, kmod-nf-conntrack
Source: https://github.com/daeuniverse/honk
License: GPL-3.0-only
Section: net
URL: https://github.com/daeuniverse/honk
Maintainer: honk
Architecture: aarch64_cortex-a53
Installed-Size: $(du -sk "$PKGDIR" 2>/dev/null | cut -f1)
Description: eBPF transparent proxy engine (honk-core) with embedded UI.
 Built from the ImmortalWrt 25.12 SDK for aarch64_cortex-a53.
 Kernel BTF is provided by the firmware (vmlinux-btf-builtin), so this
 package does not depend on vmlinux-btf.
EOF
echo
echo "control:"
cat "$CTRL"

# 5. conffiles（配置文件不覆盖用户的）
CONF="$OUT/conffiles"
printf '%s\n' /etc/config/honk /etc/honk/config.dae > "$CONF"

# 6. 组包
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/control" "$WORK/data"

# control.tar.gz
cp "$CTRL" "$WORK/control/control"
cp "$CONF" "$WORK/control/conffiles"
( cd "$WORK/control" && tar czf "$OUT/control.tar.gz" ./* 2>/dev/null )

# data.tar.gz
cp -a "$PKGDIR/." "$WORK/data/"
( cd "$WORK/data" && tar czf "$OUT/data.tar.gz" ./* 2>/dev/null )

# 7. 打 ar 包
printf '2.0\n' > "$OUT/debian-binary"
IPK="$OUT/honk_${PKGVER}_aarch64_cortex-a53.ipk"
rm -f "$IPK"

cd "$OUT"
if command -v ar >/dev/null 2>&1; then
    ar rc "$IPK" debian-binary control.tar.gz data.tar.gz
else
    echo "错误: 没有 ar 命令" >&2
    exit 1
fi

rm -f debian-binary control.tar.gz data.tar.gz control conffiles

if [ -f "$IPK" ]; then
    echo
    echo "✓ 生成: $IPK ($(wc -c < "$IPK") B)"
    echo "结构验证:"
    ar t "$IPK" 2>/dev/null | sed 's/^/  /'
else
    echo "错误: ipk 生成失败" >&2
    exit 1
fi
