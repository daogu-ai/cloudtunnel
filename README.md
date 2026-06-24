# CloudTunnel

> A lightweight macOS **menu‑bar app** to start/stop **SSH port‑forwarding tunnels** (forward *and* reverse) with one click.
>
> 一个常驻 macOS **菜单栏**的小工具，点一下即可启停 **SSH 端口转发隧道**（正向 + 反向）。

No daemon, no config files to hand‑edit, no extra dependencies — it just drives your existing `ssh` and shows live status in the menu bar.

---

## English

### What it does

You have services running on a cloud server, but the firewall / security group only exposes SSH. CloudTunnel uses your already‑configured `ssh` (keys or password) to tunnel ports in **both directions**:

| Direction | Meaning | Under the hood |
|---|---|---|
| **Forward ↓** (local → cloud) | Access a server port from your Mac at `127.0.0.1:<port>` | `ssh -L 127.0.0.1:L:127.0.0.1:R host -N` |
| **Reverse ↑** (cloud → local) | Let the server reach a service on your Mac | `ssh -R 127.0.0.1:R:127.0.0.1:L host -N` |

### Features

- 🖱 **One‑click start/stop** from the menu bar; the menu **stays open** so you can toggle several tunnels in a row.
- 🔁 **Auto‑reconnect** on drop/disconnect (2 → 5 → 10 → 30 s backoff, via `ServerAliveInterval`).
- 🟢 **Live status** dots: stopped / connecting / connected / reconnecting / error. Forward tunnels are TCP‑probed to confirm the port is really reachable.
- 🖥 **Servers as a reusable module** — define a server once (name, host, port, optional user, key **or password**), then just pick it from a dropdown when creating a tunnel.
- 🔐 **Password login** is supported: the password is stored in the **macOS Keychain** (never in plain config) and entered automatically via `expect`.
- 📝 Per‑tunnel **note**, address copy, simple create form (just a server + a port).
- 🌐 **Bilingual UI** — follows the system language (Chinese / English) automatically.
- 🚀 Optional **Launch at Login**.

### Install (download)

1. Download `CloudTunnel-<version>-macos-arm64.zip` from the [Releases](../../releases) page.
2. Unzip and drag **CloudTunnel.app** into `/Applications`.
3. Because the app is **not notarized** (no paid Apple Developer ID), Gatekeeper will warn on first launch. Either:
   - **Right‑click** the app → **Open** → **Open**, or
   - run once in Terminal:
     ```bash
     xattr -dr com.apple.quarantine /Applications/CloudTunnel.app
     ```
4. The ⇅ icon appears in the menu bar. (No Dock icon — it's a menu‑bar‑only app.)

> Requires **macOS 13+** on **Apple Silicon**. Intel users: build from source (below) — it compiles fine on x86_64.

### Prerequisites

- Passwordless SSH already set up is recommended (`~/.ssh/config` host aliases, keys). Password servers also work via the Keychain + `expect` path.
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
git clone <repo-url>
cd cloudtunnel
swift run                 # run directly (menu-bar app)
# or produce a double-clickable .app bundle:
./build-app.sh            # -> CloudTunnel.app
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

### Troubleshooting

- **“CloudTunnel is damaged / can’t be opened.”** Gatekeeper quarantine — see the `xattr` command in Install.
- **A tunnel won’t connect.** Open its submenu; hover the row for the last log line. Check the server is reachable via plain `ssh host`.
- **Reverse tunnel: server can only reach it on `127.0.0.1`.** That's by design. To let *other* machines on the server side reach it, enable `GatewayPorts yes` in the server's `sshd_config`.

### License

MIT — see [LICENSE](LICENSE).

---

## 中文

### 解决什么问题

云服务器上跑着服务，但防火墙/安全组只开了 SSH。CloudTunnel 复用你已配好的 `ssh`（密钥或密码），**双向**打通端口：

- **正向 ↓（本地→云）**：本机 `127.0.0.1:<端口>` 直接访问服务器对应端口。
- **反向 ↑（云→本地）**：让服务器能访问到你本机的服务。

### 功能

- 🖱 菜单栏**一键启停**；点开关后**菜单不收起**，可连续切换多条隧道。
- 🔁 断线/掉线**自动重连**（2→5→10→30s 退避）。
- 🟢 实时状态点：停止/建立中/已连通/重连中/出错；正向隧道做 TCP 探针确认真连通。
- 🖥 **服务器独立模块**：服务器配一次（备注名、主机、端口、可选用户、密钥或**密码**），建隧道时下拉选择即可。
- 🔐 支持**密码登录**：密码存 **macOS 钥匙串**（不落明文），用 `expect` 自动应答。
- 📝 每条隧道可加备注、复制地址；新建极简（选服务器 + 填一个端口）。
- 🌐 **中英双语**，自动跟随系统语言。
- 🚀 可选**开机自启**。

### 安装（下载）

1. 到 [Releases](../../releases) 下载 `CloudTunnel-<版本>-macos-arm64.zip`。
2. 解压，把 **CloudTunnel.app** 拖进 `/Applications`。
3. 因为没有付费 Apple 开发者签名（**未公证**），首次打开会被 Gatekeeper 拦。两种方式之一：
   - **右键** App → **打开** → **打开**；或
   - 终端执行一次：
     ```bash
     xattr -dr com.apple.quarantine /Applications/CloudTunnel.app
     ```
4. 菜单栏右上角出现 ⇅ 图标（无 Dock 图标）。

> 需 **macOS 13+**、**Apple Silicon**。Intel 用户请从源码编译（见上）。

### 使用

- 点 ⇅ 图标看隧道列表（按方向分组）。
- 点隧道行 → 弹出子菜单，**第一项是启动/停止**（点它菜单不收起，可连续切多个）。
- 同一子菜单里有**编辑 / 复制地址 / 删除**；运行中的隧道不可编辑/删除，需先停止。
- **🖥 服务器管理…** 增删改服务器。
- **＋ 新建隧道…** → 选方向、下拉选服务器、填一个端口（默认本地口=远程口）。

### 配置与数据位置

| 内容 | 位置 |
|---|---|
| 隧道 | `~/Library/Application Support/CloudTunnel/tunnels.json` |
| 服务器 | `~/Library/Application Support/CloudTunnel/servers.json` |
| 密码 | macOS 钥匙串，service `com.wuji.cloudtunnel` |

### 注意

- **反向隧道**默认只能被服务器本机（`127.0.0.1`）访问；要让服务器外的机器也访问，需在服务器 `sshd_config` 开 `GatewayPorts yes`。
- 升级时旧的 `tunnels.json`（只有 host/user）会自动迁移为引用服务器，不丢配置。

许可证：MIT。
