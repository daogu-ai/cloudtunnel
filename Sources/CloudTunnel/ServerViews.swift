import SwiftUI

/// 服务器管理窗口：列表 + 增删改。
struct ServerManagerView: View {
    @ObservedObject var store: ServerStore
    /// 某服务器被多少条隧道引用（用于阻止误删）。
    let usage: (UUID) -> Int

    /// .sheet(item:) 的目标：用身份强制重建编辑视图，保证回显。
    private struct EditTarget: Identifiable {
        let id: UUID
        let server: ServerConfig?   // nil = 新建
    }
    @State private var target: EditTarget?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L("服务器", "Servers")).font(.headline)
                Spacer()
                Button { startNew() } label: { Label(L("新建", "New"), systemImage: "plus") }
            }

            if store.servers.isEmpty {
                Text(L("还没有服务器，点右上角新建。", "No servers yet — click New."))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.servers) { s in
                        let count = usage(s.id)
                        HStack(spacing: 10) {
                            Image(systemName: s.usePassword ? "key.fill" : "lock.open")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.displayName).fontWeight(.medium)
                                Text(s.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if count > 0 {
                                Text(L("\(count) 条在用", "\(count) in use")).font(.caption).foregroundStyle(.secondary)
                            }
                            Button(L("编辑", "Edit")) { startEdit(s) }
                            Button(role: .destructive) { store.remove(s.id) } label: {
                                Text(L("删除", "Delete"))
                            }
                            .disabled(count > 0)
                            .help(count > 0 ? L("有隧道在用，无法删除", "In use by tunnels — cannot delete") : L("删除服务器", "Delete server"))
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(20)
        .frame(width: 480, height: 360)
        .sheet(item: $target) { t in
            ServerEditView(
                existing: t.server,
                onSave: { cfg, pw in
                    if t.server == nil { store.add(cfg, password: pw) } else { store.update(cfg, password: pw) }
                    target = nil
                },
                onCancel: { target = nil }
            )
        }
    }

    private func startNew() { target = EditTarget(id: UUID(), server: nil) }
    private func startEdit(_ s: ServerConfig) { target = EditTarget(id: s.id, server: s) }
}

/// 服务器新建 / 编辑表单。
struct ServerEditView: View {
    let existing: ServerConfig?
    let onSave: (ServerConfig, String?) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var host: String
    @State private var portText: String
    @State private var user: String
    @State private var usePassword: Bool
    @State private var password: String

    init(existing: ServerConfig?,
         onSave: @escaping (ServerConfig, String?) -> Void,
         onCancel: @escaping () -> Void) {
        self.existing = existing
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: existing?.name ?? "")
        _host = State(initialValue: existing?.host ?? "")
        _portText = State(initialValue: existing.map { String($0.port) } ?? "22")
        _user = State(initialValue: existing?.user ?? "")
        _usePassword = State(initialValue: existing?.usePassword ?? false)
        // 编辑已有密码服务器时，回填钥匙串里的密码。
        _password = State(initialValue: (existing?.usePassword == true)
                          ? (Keychain.password(for: existing!.id) ?? "") : "")
    }

    private var port: Int { Int(portText) ?? 0 }
    private var hostTrimmed: String { host.trimmingCharacters(in: .whitespaces) }
    /// 主机：SSH 别名 / 主机名 / IP，只允许字母数字与 . _ - :（不允许空格、中文等）。
    private var hostValid: Bool {
        !hostTrimmed.isEmpty && hostTrimmed.range(of: "^[A-Za-z0-9._:-]+$", options: .regularExpression) != nil
    }
    private var portValid: Bool { if let p = Int(portText) { return p >= 1 && p <= 65535 }; return false }
    private var isValid: Bool { hostValid && portValid && (!usePassword || !password.isEmpty) }

    private var hostError: String? {
        if host.isEmpty { return nil }
        return hostValid ? nil : L("主机只能含字母、数字和 . _ - :（不能有空格/中文）",
                                   "Host may only contain letters, digits and . _ - : (no spaces/CJK)")
    }
    private var portError: String? {
        if portText.isEmpty { return nil }
        return portValid ? nil : L("端口需为 1–65535 的数字", "Port must be a number 1–65535")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(existing == nil ? L("新建服务器", "New Server") : L("编辑服务器", "Edit Server")).font(.headline)

            field(L("备注名（选填）", "Display name (optional)")) {
                TextField(L("如：京东云 / 北京", "e.g. JD Cloud / Beijing"), text: $name)
            }
            HStack(alignment: .top, spacing: 12) {
                field(L("主机 (SSH 别名或 IP)", "Host (SSH alias or IP)")) {
                    TextField(L("vps-jd 或 1.2.3.4", "vps-jd or 1.2.3.4"), text: $host).frame(width: 180)
                }
                field(L("端口", "Port")) {
                    TextField("22", text: $portText).frame(width: 70)
                        .onChange(of: portText) { v in
                            let d = String(v.filter { $0.isNumber }.prefix(5))
                            if d != portText { portText = d }
                        }
                }
            }
            if let msg = hostError ?? portError { Text(msg).font(.caption).foregroundStyle(.red) }
            field(L("用户（选填）", "User (optional)")) {
                TextField(L("默认：本地用户", "default: local user"), text: $user).frame(width: 180)
            }

            Toggle(L("使用密码登录（否则走免密 / 密钥）", "Use password login (otherwise key/agent)"), isOn: $usePassword)
                .toggleStyle(.checkbox)
            if usePassword {
                field(L("密码", "Password")) {
                    SecureField(L("登录密码（存入钥匙串）", "Login password (stored in Keychain)"), text: $password).frame(width: 260)
                }
                Text(L("密码保存在 macOS 钥匙串，通过 expect 自动应答；不写入明文配置。",
                       "Password is stored in the macOS Keychain and entered via expect; never written to plain config."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Divider()
            HStack {
                Spacer()
                Button(L("取消", "Cancel"), action: onCancel).keyboardShortcut(.cancelAction)
                Button(existing == nil ? L("创建", "Create") : L("保存", "Save")) {
                    let cfg = ServerConfig(
                        id: existing?.id ?? UUID(),
                        name: name.trimmingCharacters(in: .whitespaces),
                        host: host.trimmingCharacters(in: .whitespaces),
                        port: port,
                        user: user.trimmingCharacters(in: .whitespaces),
                        usePassword: usePassword)
                    onSave(cfg, usePassword ? password : nil)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 420)
        .textFieldStyle(.roundedBorder)
    }

    @ViewBuilder
    private func field<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            content()
        }
    }
}
