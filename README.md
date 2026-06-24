<div align="center">

# CloudTunnel

**A lightweight macOS menu‑bar app to start/stop SSH port‑forwarding tunnels (forward & reverse) with one click.**

**常驻 macOS 菜单栏的小工具，点一下即可启停 SSH 端口转发隧道（正向 + 反向）。**

[![Release](https://img.shields.io/github/v/release/daogu-ai/cloudtunnel?sort=semver)](https://github.com/daogu-ai/cloudtunnel/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/daogu-ai/cloudtunnel/total)](https://github.com/daogu-ai/cloudtunnel/releases)
[![Platform](https://img.shields.io/badge/macOS-13%2B-blue)](https://github.com/daogu-ai/cloudtunnel)
[![Arch](https://img.shields.io/badge/arch-Apple%20Silicon-black)](https://github.com/daogu-ai/cloudtunnel/releases/latest)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org)
[![License](https://img.shields.io/github/license/daogu-ai/cloudtunnel)](LICENSE)

**[English](#english)** · **[中文](#中文)**

</div>

No daemon, no config files to hand‑edit, no extra dependencies — it just drives your existing `ssh` and shows live status in the menu bar.

```
        ⇅   ← menu-bar icon
   ┌────────────────────────────────────────────┐
   │  CloudTunnel · JD Cloud                     │
   ├────────────────────────────────────────────┤
   │  Forward ↓ local → cloud                    │
   │   🟢  Server 11812 — 127.0.0.1:11812 · JD ▸ │──┐
   │  Reverse ↑ cloud → local                    │  │   ┌──────────────────┐
   │   🟢  Local 5030 → cloud — JD:5030        ▸ │  └──▶│ ⏸  Stop          │ (keeps menu open)
   ├────────────────────────────────────────────┤      │ 🔗 127.0.0.1:11812│
   │  ＋ New Tunnel…                              │      │ ✎  Edit…         │
   │  🖥 Manage Servers…                          │      │ ⧉  Copy Address  │
   │  ⟳ Reconnect All     ⏻ Stop All             │      │ 🗑  Delete        │
   │  Launch at Login         Quit               │      └──────────────────┘
   └────────────────────────────────────────────┘
```

---

## English

### What it does

You have services running on a cloud server, but the firewall / security group only exposes SSH. CloudTunnel uses your already‑configured `ssh` (keys or password) to tunnel ports in **both directions**:

| Direction | Meaning | Under the hood |
|---|---|---|
| **Forward ↓** (local → cloud) | Access a server port from your Mac at `127.0.0.1:<port>` | `ssh -L 127.0.0.1:L:127.0.0.1:R host -N` |
| **Reverse ↑** (cloud → local) | Let the server reach a service on your Mac | `ssh -R 127.0.0.1:R:127.0.0.1:L host -N` |

### Features

- 🖱 **One‑click start/stop** from the menu bar; the toggle is a *stay‑open* item so you can flip several tunnels in a row without the menu closing.
- 🔁 **Auto‑reconnect** on drop/disconnect (2 → 5 → 10 → 30 s backoff, via `ServerAliveInterval`).
- 🟢 **Live status** dots: stopped / connecting / connected / reconnecting / error. Forward tunnels are TCP‑probed to confirm the port is really reachable.
- 🖥 **Servers as a reusable module** — define a server once (name, host, port, optional user, key **or password**), then just pick it from a dropdown when creating a tunnel.
- 🔐 **Password login** supported: the password is stored in the **macOS Keychain** (never in plain config) and entered automatically via `expect`.
- 📝 Per‑tunnel **note**, address copy, dead‑simple create form (just a server + a port).
- 🌐 **Bilingual UI** — follows the system language (Chinese / English) automatically.
- 🚀 Optional **Launch at Login**.

### Install (download)

1. Download `CloudTunnel-<version>-macos-arm64.zip` from the [latest release](https://github.com/daogu-ai/cloudtunnel/releases/latest).
2. Unzip and drag **CloudTunnel.app** into `/Applications`.
3. The app is **not notarized** (no paid Apple Developer ID), so Gatekeeper warns on first launch. Either:
   - **Right‑click** the app → **Open** → **Open**, or
   - run once in Terminal:
     ```bash
     xattr -dr com.apple.quarantine /Applications/CloudTunnel.app
     ```
4. The ⇅ icon appears in the menu bar. (No Dock icon — it's a menu‑bar‑only app.)

> Requires **macOS 13+** on **Apple Silicon**. Intel users: build from source (below) — it compiles fine on x86_64.

### Prerequisites

- Passwordless SSH set up is recommended (`~/.ssh/config` host aliases, keys). Password servers also work via the Keychain + `expect` path.
- `/usr/bin/ssh` and `/usr/bin/expect` (both ship with macOS).

### Usage

- Click the ⇅ menu‑bar icon to see your tunnels grouped by direction.
- Click a tunnel row → its submenu opens; the **first item is Start/Stop** (clicking it keeps the menu open so you can toggle more).
- The same submenu has **Edit**, **Copy Address**, **Delete**. Running tunnels can't be edited/deleted — stop them first.
- **🖥 Manage Servers…** to add/edit/delete servers.
- **＋ New Tunnel…** → pick direction, pick a server, type one port (local = remote by default), done.

### How servers / passwords work

- Servers live in `servers.json` (no secrets). A server is `name + host + port + user + auth`.
- **Key/agent** servers run `ssh` directly with `BatchMode=yes`.
- **Password** servers run through `/usr/bin/expect`, which spawns `ssh` and answers the `password:` prompt. The password is read from the **Keychain** and passed to `expect` via an **environment variable** (never as a command‑line argument, so it won't show up in `ps`).

### Auto‑reconnect

Each tunnel is a supervised `ssh -N` child process with `ExitOnForwardFailure=yes` (fail fast on bind errors) and `ServerAliveInterval=15 / ServerAliveCountMax=3` (detect dead links in ~45 s). If the process exits while the tunnel is meant to be on, it is respawned with exponential backoff (2/5/10/30 s).

### Config & data locations

| What | Where |
|---|---|
| Tunnels | `~/Library/Application Support/CloudTunnel/tunnels.json` |
| Servers | `~/Library/Application Support/CloudTunnel/servers.json` |
| Passwords | macOS Keychain, service `com.wuji.cloudtunnel` |

### Build from source

```bash
git clone https://github.com/daogu-ai/cloudtunnel.git
cd cloudtunnel
swift run                 # run directly (menu-bar app)
./build-app.sh            # or produce a double-clickable CloudTunnel.app
```

Project layout (`Sources/CloudTunnel/`):

| File | Role |
|---|---|
| `Models.swift` | `ServerConfig` / `TunnelConfig`, direction, status, ssh arg building |
| `Keychain.swift` | server password storage in the Keychain |
| `ServerStore.swift` | server list persistence (`ObservableObject`) |
| `TunnelManager.swift` | persistence, process lifecycle, auto‑reconnect, health probe, password via `expect` |
| `AddEditView.swift` | tunnel create/edit form (server dropdown) |
| `ServerViews.swift` | server manager + server edit form |
| `StayOpenItemView.swift` | the stay‑open Start/Stop menu item |
| `AppController.swift` | menu‑bar UI, windows, launch‑at‑login |
| `Localization.swift` | tiny zh/en string helper |
| `main.swift` | entry point |

### Signing & notarization (maintainers)

The published zip is **ad‑hoc signed** and therefore not notarized — end users must clear quarantine once (see Install). To ship a “double‑click, no warning” build you need a **paid Apple Developer ID**. Once you have it:

```bash
# 1) one-time: store notarization credentials in the keychain
xcrun notarytool store-credentials cloudtunnel-notary \
  --apple-id "you@example.com" --team-id "TEAMID" --password "app-specific-password"

# 2) build, signed with your Developer ID (hardened runtime)
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./build-app.sh

# 3) notarize + staple + repackage the release zip
./notarize.sh cloudtunnel-notary
```

- `build-app.sh` signs ad‑hoc by default; set `CODESIGN_IDENTITY` to sign with your Developer ID and enable the hardened runtime.
- `notarize.sh` zips the app, submits to Apple, waits, staples the ticket, and rebuilds `dist/CloudTunnel-1.0.0-macos-arm64.zip` ready for upload.

### Troubleshooting

- **“CloudTunnel is damaged / can’t be opened.”** Gatekeeper quarantine — see the `xattr` command in Install.
- **A tunnel won’t connect.** Open its submenu; hover the row for the last log line. Check the server is reachable via plain `ssh host`.
- **Reverse tunnel: server can only reach it on `127.0.0.1`.** By design. To let *other* machines on the server side reach it, enable `GatewayPorts yes` in the server's `sshd_config`.

### License

MIT — see [LICENSE](LICENSE).

---

## 中文

### 解决什么问题

云服务器上跑着服务，但防火墙/安全组只开了 SSH。CloudTunnel 复用你已配好的 `ssh`（密钥或密码），**双向**打通端口：

| 方向 | 含义 | 底层命令 |
|---|---|---|
| **正向 ↓**（本地→云） | 本机 `127.0.0.1:<端口>` 直接访问服务器对应端口 | `ssh -L 127.0.0.1:本地:127.0.0.1:远程 host -N` |
| **反向 ↑**（云→本地） | 让服务器能访问到你本机的服务 | `ssh -R 127.0.0.1:远程:127.0.0.1:本地 host -N` |

### 功能

- 🖱 菜单栏**一键启停**；开关是「常驻项」，点了**菜单不收起**，可连续切换多条隧道。
- 🔁 断线/掉线**自动重连**（2→5→10→30s 退避）。
- 🟢 实时状态点：停止 / 建立中 / 已连通 / 重连中 / 出错；正向隧道做 TCP 探针确认真连通。
- 🖥 **服务器独立模块**：服务器配一次（备注名、主机、端口、可选用户、密钥或**密码**），建隧道时下拉选择即可。
- 🔐 支持**密码登录**：密码存 **macOS 钥匙串**（不落明文），用 `expect` 自动应答，且通过环境变量传入、不出现在 `ps`。
- 📝 每条隧道可加备注、复制地址；新建极简（选服务器 + 填一个端口）。
- 🌐 **中英双语**，自动跟随系统语言。
- 🚀 可选**开机自启**。

### 安装（下载）

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

### 前置条件

- 建议已配好 SSH 免密（`~/.ssh/config` 别名 + 密钥）；密码服务器也支持（走钥匙串 + `expect`）。
- `/usr/bin/ssh` 与 `/usr/bin/expect`（macOS 自带）。

### 使用

- 点 ⇅ 图标看隧道列表（按方向分组）。
- 点隧道行 → 弹出子菜单，**第一项是启动/停止**（点它菜单不收起，可连续切多个）。
- 同一子菜单里有**编辑 / 复制地址 / 删除**；运行中的隧道不可编辑/删除，需先停止。
- **🖥 服务器管理…** 增删改服务器。
- **＋ 新建隧道…** → 选方向、下拉选服务器、填一个端口（默认本地口=远程口）。

### 服务器 / 密码原理

- 服务器存在 `servers.json`（不含密钥/密码）。一台服务器 = `备注名 + 主机 + 端口 + 用户 + 登录方式`。
- **密钥/agent** 服务器直接 `ssh`（`BatchMode=yes`）。
- **密码**服务器走 `/usr/bin/expect`，由它拉起 `ssh` 并自动应答 `password:`；密码从**钥匙串**读出、经**环境变量**传给 expect，不进命令行参数（`ps` 看不到）。

### 自动重连

每条隧道是被托管的 `ssh -N` 子进程，带 `ExitOnForwardFailure=yes`（绑定失败立即退出）和 `ServerAliveInterval=15 / ServerAliveCountMax=3`（约 45s 内感知断链）。只要隧道处于"应开启"状态而进程退出，就按 2/5/10/30s 退避自动重连。

### 配置与数据位置

| 内容 | 位置 |
|---|---|
| 隧道 | `~/Library/Application Support/CloudTunnel/tunnels.json` |
| 服务器 | `~/Library/Application Support/CloudTunnel/servers.json` |
| 密码 | macOS 钥匙串，service `com.wuji.cloudtunnel` |

### 从源码编译

```bash
git clone https://github.com/daogu-ai/cloudtunnel.git
cd cloudtunnel
swift run                 # 直接运行（菜单栏 App）
./build-app.sh            # 或打包成可双击的 CloudTunnel.app
```

### 签名与公证（维护者）

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

### 常见问题

- **"CloudTunnel 已损坏 / 无法打开"**：Gatekeeper 隔离，见"安装"里的 `xattr` 命令。
- **某隧道连不上**：打开它的子菜单，把鼠标停在行上看最后一条日志；先用 `ssh host` 确认服务器可达。
- **反向隧道：服务器只能在 `127.0.0.1` 访问**：这是默认行为；要让服务器外的机器也访问，需在服务器 `sshd_config` 开 `GatewayPorts yes`。

### 许可证

MIT，见 [LICENSE](LICENSE)。
