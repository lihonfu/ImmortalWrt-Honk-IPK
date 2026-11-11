# ImmortalWrt-Honk-IPK

只编译 **honk** 单个包，产出 `aarch64_cortex-a53` 的 ipk。

**用途**：路由器不用刷固件，直接 `opkg install` 就能升级 honk。

---

## 自动触发

- **每周一 03:00 UTC** 自动检查 honk 是否有新版，有则编译
- 已存在的版本会跳过（不重复编译）

## 手动触发

Actions → **Build honk IPK** → Run workflow

| 参数 | 说明 |
|---|---|
| `honk_tag` | 留空自动取最新；填 `v0.1.0-beta.6` 可锁定版本 |

## 产物

Release 里保留最新 3 个版本：

```
honk_0.1.0_beta6_aarch64_cortex-a53.ipk
```

## 路由器安装

### 手动

```sh
cd /tmp
wget https://github.com/lihonfu/ImmortalWrt-Honk-IPK/releases/latest/download/honk_*.ipk
opkg install --force-reinstall honk_*.ipk
/etc/init.d/honk restart
```

### 自动脚本

见 `update-honk.sh`（部署在路由器 `/usr/bin/update-honk.sh`）：

```sh
update-honk.sh check    # 只检查有没有新版
update-honk.sh update   # 下载并安装最新版
```

## 编译配置

| 项 | 值 |
|---|---|
| SDK | ImmortalWrt 25.12 snapshot |
| 架构 | aarch64_cortex-a53 |
| 目标 | mediatek/filogic |
| 内核 BTF | 启用（eBPF 必需）|
| Rust | 1.99.1 + nightly-2026-10-20 + bpf-linker v0.13.0 |

## 已知坑

编译时强制设置这些符号，否则 BTF 会被静默禁用：

```
CONFIG_BUILDBOT=y
CONFIG_KERNEL_DEBUG_INFO=y
# CONFIG_KERNEL_DEBUG_INFO_REDUCED is not set
CONFIG_KERNEL_DEBUG_INFO_BTF=y
```
