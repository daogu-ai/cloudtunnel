<div align="center">

# CloudTunnel

**A lightweight macOS menu‑bar app to start/stop SSH port‑forwarding tunnels (forward & reverse) with one click.**

[![Release](https://img.shields.io/github/v/release/daogu-ai/cloudtunnel?sort=semver)](https://github.com/daogu-ai/cloudtunnel/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/daogu-ai/cloudtunnel/total)](https://github.com/daogu-ai/cloudtunnel/releases)
[![Platform](https://img.shields.io/badge/macOS-13%2B-blue)](https://github.com/daogu-ai/cloudtunnel)
[![Arch](https://img.shields.io/badge/arch-Apple%20Silicon-black)](https://github.com/daogu-ai/cloudtunnel/releases/latest)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org)
[![License](https://img.shields.io/github/license/daogu-ai/cloudtunnel)](LICENSE)

**English** · **[中文](README.zh-CN.md)**

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

## What it does

You have services running on a cloud server, but the firewall / security group only exposes SSH. CloudTunnel uses your already‑configured `ssh` (keys or password) to tunnel ports in **both directions**:

| Direction | Meaning | Under the hood |
|---|---|---|
| **Forward ↓** (local → cloud) | Access a server port from your Mac at `127.0.0.1:<port>` | `ssh -L 127.0.0.1:L:127.0.0.1:R host -N` |
| **Reverse ↑** (cloud → local) | Let the server reach a service on your Mac | `ssh -R 127.0.0.1:R:127.0.0.1:L host -N` |

## Features

- 🖱 **One‑click start/stop** from the menu bar; the toggle is a *stay‑open* item so you can flip several tunnels in a row without the menu closing.
- 🔁 **Auto‑reconnect** on drop/disconnect (2 → 5 → 10 → 30 s backoff, via `ServerAliveInterval`).
- 🟢 **Live status** dots: stopped / connecting / connected / reconnecting / error. Forward tunnels are TCP‑probed to confirm the port is really reachable.
- 🖥 **Servers as a reusable module** — define a server once (name, host, port, optional user, key **or password**), then just pick it from a dropdown when creating a tunnel.
- 🔐 **Password login** supported: the password is stored in the **macOS Keychain** (never in plain config) and entered automatically via `expect`.
- 📝 Per‑tunnel **note**, address copy, dead‑simple create form (just a server + a port).
- 🌐 **Bilingual UI** — follows the system language (Chinese / English) automatically.
- 🚀 Optional **Launch at Login**.

## Install (download)

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

## Prerequisites

- Passwordless SSH set up is recommended (`~/.ssh/config` host aliases, keys). Password servers also work via the Keychain + `expect` path.
- `/usr/bin/ssh` and `/usr/bin/expect` (both ship with macOS).

## Usage

- Click the ⇅ menu‑bar icon to see your tunnels grouped by direction.
- Click a tunnel row → its submenu opens; the **first item is Start/Stop** (clicking it keeps the menu open so you can toggle more).
- The same submenu has **Edit**, **Copy Address**, **Delete**. Running tunnels can't be edited/deleted — stop them first.
- **🖥 Manage Servers…** to add/edit/delete servers.
- **＋ New Tunnel…** → pick direction, pick a server, type one port (local = remote by default), done.

## How servers / passwords work

- Servers live in `servers.json` (no secrets). A server is `name + host + port + user + auth`.
- **Key/agent** servers run `ssh` directly with `BatchMode=yes`.
- **Password** servers run through `/usr/bin/expect`, which spawns `ssh` and answers the `password:` prompt. The password is read from the **Keychain** and passed to `expect` via an **environment variable** (never as a command‑line argument, so it won't show up in `ps`).

## Auto‑reconnect

Each tunnel is a supervised `ssh -N` child process with `ExitOnForwardFailure=yes` (fail fast on bind errors) and `ServerAliveInterval=15 / ServerAliveCountMax=3` (detect dead links in ~45 s). If the process exits while the tunnel is meant to be on, it is respawned with exponential backoff (2/5/10/30 s).

## Config & data locations

| What | Where |
|---|---|
| Tunnels | `~/Library/Application Support/CloudTunnel/tunnels.json` |
| Servers | `~/Library/Application Support/CloudTunnel/servers.json` |
| Passwords | macOS Keychain, service `com.wuji.cloudtunnel` |

## Build from source

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

## Signing & notarization (maintainers)

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

## Troubleshooting

- **“CloudTunnel is damaged / can’t be opened.”** Gatekeeper quarantine — see the `xattr` command in Install.
- **A tunnel won’t connect.** Open its submenu; hover the row for the last log line. Check the server is reachable via plain `ssh host`.
- **Reverse tunnel: server can only reach it on `127.0.0.1`.** By design. To let *other* machines on the server side reach it, enable `GatewayPorts yes` in the server's `sshd_config`.

## License

MIT — see [LICENSE](LICENSE).
