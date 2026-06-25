import SwiftUI

/// 极简的新建 / 编辑隧道表单：选服务器 + 填端口。
struct AddEditView: View {
    let existing: TunnelConfig?
    @ObservedObject var serverStore: ServerStore
    let onSave: (TunnelConfig) -> Void
    let onDelete: ((UUID) -> Void)?
    let onCancel: () -> Void
    let onManageServers: () -> Void

    @State private var direction: Direction
    @State private var name: String
    @State private var serverID: UUID?
    @State private var localPortText: String
    @State private var remotePortText: String
    @State private var note: String
    @State private var samePort: Bool
    @State private var autoStart: Bool

    init(existing: TunnelConfig?,
         serverStore: ServerStore,
         onSave: @escaping (TunnelConfig) -> Void,
         onDelete: ((UUID) -> Void)?,
         onCancel: @escaping () -> Void,
         onManageServers: @escaping () -> Void) {
        self.existing = existing
        self.serverStore = serverStore
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        self.onManageServers = onManageServers
        _direction = State(initialValue: existing?.direction ?? .forward)
        _name = State(initialValue: existing?.name ?? "")
        _serverID = State(initialValue: existing?.serverID ?? serverStore.servers.first?.id)
        _localPortText = State(initialValue: existing.map { String($0.localPort) } ?? "")
        _remotePortText = State(initialValue: existing.map { String($0.remotePort) } ?? "")
        _note = State(initialValue: existing?.note ?? "")
        _samePort = State(initialValue: existing.map { $0.localPort == $0.remotePort } ?? true)
        _autoStart = State(initialValue: existing?.autoStart ?? false)
    }

    private var localPort: Int { Int(localPortText) ?? 0 }
    private var remotePort: Int { samePort ? localPort : (Int(remotePortText) ?? 0) }
    private var selectedServer: ServerConfig? { serverStore.server(for: serverID) }
    private var isValid: Bool {
        serverID != nil && localPort > 0 && localPort < 65536 && remotePort > 0 && remotePort < 65536
    }

    private var previewConfig: TunnelConfig {
        TunnelConfig(id: existing?.id ?? UUID(),
                     name: name.isEmpty ? defaultName : name,
                     direction: direction, serverID: serverID,
                     localPort: localPort, remotePort: remotePort,
                     note: note, autoStart: autoStart)
    }
    private var defaultName: String {
        direction == .forward ? L("服务器 \(remotePort)", "Server \(remotePort)")
                              : L("本地 \(localPort) → 云", "Local \(localPort) → cloud")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(existing == nil ? L("新建隧道", "New Tunnel") : L("编辑隧道", "Edit Tunnel")).font(.headline)

            // 方向
            section(L("方向", "Direction")) {
                Picker("", selection: $direction) {
                    Text(L("正向 ↓ 本地访问云", "Forward ↓ local → cloud")).tag(Direction.forward)
                    Text(L("反向 ↑ 云访问本地", "Reverse ↑ cloud → local")).tag(Direction.reverse)
                }
                .pickerStyle(.radioGroup).labelsHidden()
            }

            // 服务器（下拉选择）
            section(L("服务器", "Server")) {
                HStack(spacing: 8) {
                    Picker("", selection: $serverID) {
                        if serverStore.servers.isEmpty {
                            Text(L("（无，请先新建服务器）", "(none — create a server first)")).tag(UUID?.none)
                        }
                        ForEach(serverStore.servers) { s in
                            Text("\(s.displayName)   —   \(s.subtitle)").tag(Optional(s.id))
                        }
                    }
                    .labelsHidden().frame(maxWidth: 280)
                    Button(L("管理…", "Manage…")) { onManageServers() }
                }
            }

            // 端口（本地 → 远程，始终都显示；默认远程跟随本地）
            section(L("端口", "Ports")) {
                HStack(alignment: .bottom, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("本地", "Local")).font(.caption).foregroundStyle(.secondary)
                        TextField(L("如 5100", "e.g. 5100"), text: $localPortText).frame(width: 110)
                    }
                    Text("→").padding(.bottom, 5).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("远程", "Remote")).font(.caption).foregroundStyle(.secondary)
                        TextField(L("如 5200", "e.g. 5200"),
                                  text: samePort ? .constant(localPortText) : $remotePortText)
                            .frame(width: 110)
                            .disabled(samePort)
                    }
                }
                .textFieldStyle(.roundedBorder)
                Toggle(L("远程端口与本地相同（默认）", "Remote port same as local (default)"), isOn: $samePort)
                    .toggleStyle(.checkbox).font(.callout)
            }

            // 名称 + 备注
            section(L("名称（选填）", "Name (optional)")) {
                TextField(defaultName, text: $name).textFieldStyle(.roundedBorder)
            }
            section(L("备注（这条隧道用来干啥）", "Note (what this tunnel is for)")) {
                TextField(L("如：访问云上 Postgres", "e.g. access cloud Postgres"), text: $note).textFieldStyle(.roundedBorder)
            }

            Toggle(L("此隧道随 App 启动自动连接", "Auto-connect this tunnel on app launch"), isOn: $autoStart).toggleStyle(.checkbox).font(.callout)

            // 命令预览
            section(L("预览", "Preview")) {
                Text(isValid ? previewConfig.previewCommand(server: selectedServer)
                             : L("选择服务器并填写有效端口后生成命令…", "Pick a server and valid ports to see the command…"))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Divider()
            HStack {
                if let existing, let onDelete {
                    Button(role: .destructive) { onDelete(existing.id) } label: {
                        Text(L("删除", "Delete")).foregroundStyle(.red)
                    }
                }
                Spacer()
                Button(L("取消", "Cancel"), action: onCancel).keyboardShortcut(.cancelAction)
                Button(existing == nil ? L("创建", "Create") : L("保存", "Save")) { onSave(previewConfig) }
                    .keyboardShortcut(.defaultAction).disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    @ViewBuilder
    private func section<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            content()
        }
    }
}
