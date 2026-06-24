<div align="center">

# CloudTunnel

**常驻 macOS 菜单栏的小工具，点一下即可启停 SSH 端口转发隧道（正向 + 反向）。**

[![Release](https://img.shields.io/github/v/release/daogu-ai/cloudtunnel?sort=semver)](https://github.com/daogu-ai/cloudtunnel/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/daogu-ai/cloudtunnel/total)](https://github.com/daogu-ai/cloudtunnel/releases)
[![Platform](https://img.shields.io/badge/macOS-13%2B-blue)](https://github.com/daogu-ai/cloudtunnel)
[![Arch](https://img.shields.io/badge/arch-Apple%20Silicon-black)](https://github.com/daogu-ai/cloudtunnel/releases/latest)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org)
[![License](https://img.shields.io/github/license/daogu-ai/cloudtunnel)](LICENSE)

**[English](README.md)** · **中文**

</div>

无后台守护、无需手改配置文件、零额外依赖 —— 它只是驱动你已有的 `ssh`，并在菜单栏显示实时状态。

```
        ⇅   ← 菜单栏图标
   ┌────────────────────────────────────────────┐
   │  CloudTunnel · 京东云                        │
   ├────────────────────────────────────────────┤
   │  正向 ↓ 本地访问云                            │
   │   🟢  服务器 11812 — 127.0.0.1:11812 · 京东 ▸│──┐
   │  反向 ↑ 云访问本地                            │  │   ┌──────────────────┐
   │   🟢  本地 5030 → 云 — 京东:5030           ▸ │  └──▶│ ⏸  停止          │ (菜单不收起)
   ├────────────────────────────────────────────┤      │ 🔗 127.0.0.1:11812│
   │  ＋ 新建隧道…                                │      │ ✎  编辑…         │
   │  🖥 服务器管理…                              │      │ ⧉  复制地址      │
   │  ⟳ 全部重连     ⏻ 全部停止                  │      │ 🗑  删除          │
   │  开机自启         退出                       │      └──────────────────┘
   └────────────────────────────────────────────┘
```

## 解决什么问题

云服务器上跑着服务，但防火墙/安全组只开了 SSH。CloudTunnel 复用你已配好的 `ssh`（密钥或密码），**双向**打通端口：

| 方向 | 含义 | 底层命令 |
|---|---|---|
| **正向 ↓**（本地→云） | 本机 `127.0.0.1:<端口>` 直接访问服务器对应端口 | `ssh -L 127.0.0.1:本地:127.0.0.1:远程 host -N` |
| **反向 ↑**（云→本地） | 让服务器能访问到你本机的服务 | `ssh -R 127.0.0.1:远程:127.0.0.1:本地 host -N` |

## 功能

- 🖱 菜单栏**一键启停**；开关是「常驻项」，点了**菜单不收起**，可连续切换多条隧道。
- 🔁 断线/掉线**自动重连**（2→5→10→30s 退避）。
- 🟢 实时状态点：停止 / 建立中 / 已连通 / 重连中 / 出错；正向隧道做 TCP 探针确认真连通。
- 🖥 **服务器独立模块**：服务器配一次（备注名、主机、端口、可选用户、密钥或**密码**），建隧道时下拉选择即可。
- 🔐 支持**密码登录**：密码存 **macOS 钥匙串**（不落明文），用 `expect` 自动应答，且通过环境变量传入、不出现在 `ps`。
- 📝 每条隧道可加备注、复制地址；新建极简（选服务器 + 填一个端口）。
- 🌐 **中英双语**，自动跟随系统语言。
- 🚀 可选**开机自启**。

## 安装（下载）

1. 到 [最新 Release](https://github.com/daogu-ai/cloudtunnel/releases/latest) 下载 `CloudTunnel-<版本>-macos-arm64.zip`。
2. 解压，把 **CloudTunnel.app** 拖进 `/Applications`。
3. 因为没有付费 Apple 开发者签名（**未公证**），首次打开会被 Gatekeeper 拦。两种方式之一：
   - **右键** App → **打开** → **打开**；或
   - 终端执行一次：
     ```bash
     xattr -dr com.apple.quarantine /Applications/CloudTunnel.app
     ```
4. 菜单栏右上角出现 ⇅ 图标（无 Dock 图标）。

> 需 **macOS 13+**、**Apple Silicon**。Intel 用户请从源码编译（见下）。

## 前置条件

- 建议已配好 SSH 免密（`~/.ssh/config` 别名 + 密钥）；密码服务器也支持（走钥匙串 + `expect`）。
- `/usr/bin/ssh` 与 `/usr/bin/expect`（macOS 自带）。

## 使用

- 点 ⇅ 图标看隧道列表（按方向分组）。
- 点隧道行 → 弹出子菜单，**第一项是启动/停止**（点它菜单不收起，可连续切多个）。
- 同一子菜单里有**编辑 / 复制地址 / 删除**；运行中的隧道不可编辑/删除，需先停止。
- **🖥 服务器管理…** 增删改服务器。
- **＋ 新建隧道…** → 选方向、下拉选服务器、填一个端口（默认本地口=远程口）。

## 服务器 / 密码原理

- 服务器存在 `servers.json`（不含密钥/密码）。一台服务器 = `备注名 + 主机 + 端口 + 用户 + 登录方式`。
- **密钥/agent** 服务器直接 `ssh`（`BatchMode=yes`）。
- **密码**服务器走 `/usr/bin/expect`，由它拉起 `ssh` 并自动应答 `password:`；密码从**钥匙串**读出、经**环境变量**传给 expect，不进命令行参数（`ps` 看不到）。

## 自动重连

每条隧道是被托管的 `ssh -N` 子进程，带 `ExitOnForwardFailure=yes`（绑定失败立即退出）和 `ServerAliveInterval=15 / ServerAliveCountMax=3`（约 45s 内感知断链）。只要隧道处于"应开启"状态而进程退出，就按 2/5/10/30s 退避自动重连。

## 配置与数据位置

| 内容 | 位置 |
|---|---|
| 隧道 | `~/Library/Application Support/CloudTunnel/tunnels.json` |
| 服务器 | `~/Library/Application Support/CloudTunnel/servers.json` |
| 密码 | macOS 钥匙串，service `com.wuji.cloudtunnel` |

## 从源码编译

```bash
git clone https://github.com/daogu-ai/cloudtunnel.git
cd cloudtunnel
swift run                 # 直接运行（菜单栏 App）
./build-app.sh            # 或打包成可双击的 CloudTunnel.app
```

源码结构（`Sources/CloudTunnel/`）：

| 文件 | 职责 |
|---|---|
| `Models.swift` | `ServerConfig` / `TunnelConfig`、方向、状态、ssh 参数生成 |
| `Keychain.swift` | 服务器密码存取（钥匙串） |
| `ServerStore.swift` | 服务器清单持久化（`ObservableObject`） |
| `TunnelManager.swift` | 持久化、进程生命周期、自动重连、健康探针、密码 `expect` |
| `AddEditView.swift` | 隧道新建/编辑表单（下拉选服务器） |
| `ServerViews.swift` | 服务器管理 + 服务器编辑表单 |
| `StayOpenItemView.swift` | 常驻"启动/停止"菜单项 |
| `AppController.swift` | 菜单栏 UI、窗口、开机自启 |
| `Localization.swift` | 轻量 zh/en 文案助手 |
| `main.swift` | 入口 |

## 签名与公证（维护者）

发布的 zip 是 **ad‑hoc 签名**、未公证，所以终端用户首次要解除隔离（见"安装"）。要做到"双击即开、零提示"，需要**付费 Apple 开发者账号**。有了之后：

```bash
# 1) 一次性：把公证凭证存进钥匙串
xcrun notarytool store-credentials cloudtunnel-notary \
  --apple-id "you@example.com" --team-id "TEAMID" --password "应用专用密码"

# 2) 用 Developer ID 签名构建（开启 hardened runtime）
CODESIGN_IDENTITY="Developer ID Application: 你的名字 (TEAMID)" ./build-app.sh

# 3) 公证 + staple + 重新打包发布 zip
./notarize.sh cloudtunnel-notary
```

- `build-app.sh` 默认 ad‑hoc 签名；设置 `CODESIGN_IDENTITY` 即用 Developer ID 签名并启用 hardened runtime。
- `notarize.sh` 会打包提交 Apple、等待、staple 票据，并重建可上传的 `dist/CloudTunnel-1.0.0-macos-arm64.zip`。

## 常见问题

- **"CloudTunnel 已损坏 / 无法打开"**：Gatekeeper 隔离，见"安装"里的 `xattr` 命令。
- **某隧道连不上**：打开它的子菜单，把鼠标停在行上看最后一条日志；先用 `ssh host` 确认服务器可达。
- **反向隧道：服务器只能在 `127.0.0.1` 访问**：这是默认行为；要让服务器外的机器也访问，需在服务器 `sshd_config` 开 `GatewayPorts yes`。

## 许可证

MIT，见 [LICENSE](LICENSE)。
