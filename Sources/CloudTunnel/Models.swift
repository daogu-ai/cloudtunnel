import Foundation

/// 隧道方向。
/// - forward (`-L`): 本地开监听口，流量经 SSH 打到云服务器侧目标 —— "本地访问云"。
/// - reverse (`-R`): 云服务器开监听口，流量回流到本机目标 —— "云访问本地"。
enum Direction: String, Codable {
    case forward
    case reverse

    var label: String {
        self == .forward ? L("正向 ↓ 本地访问云", "Forward ↓ local → cloud")
                         : L("反向 ↑ 云访问本地", "Reverse ↑ cloud → local")
    }
    var shortLabel: String { self == .forward ? L("正向 ↓", "Fwd ↓") : L("反向 ↑", "Rev ↑") }
}

// MARK: - 服务器

/// 一台可复用的服务器配置。密码不存在这里（存钥匙串），只记是否用密码。
struct ServerConfig: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String          // 备注名，如"京东云 / 北京"
    var host: String          // SSH 别名或 IP
    var port: Int = 22
    var user: String = ""     // 空 = 本地用户名（免用户名）
    var usePassword: Bool = false   // true 时密码存钥匙串

    private enum CodingKeys: String, CodingKey { case id, name, host, port, user, usePassword }
    init(id: UUID = UUID(), name: String, host: String, port: Int = 22,
         user: String = "", usePassword: Bool = false) {
        self.id = id; self.name = name; self.host = host
        self.port = port; self.user = user; self.usePassword = usePassword
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        host = try c.decode(String.self, forKey: .host)
        port = try c.decodeIfPresent(Int.self, forKey: .port) ?? 22
        user = try c.decodeIfPresent(String.self, forKey: .user) ?? ""
        usePassword = try c.decodeIfPresent(Bool.self, forKey: .usePassword) ?? false
    }

    /// ssh 连接目标：有用户名则 user@host，否则纯 host。
    var sshTarget: String { user.isEmpty ? host : "\(user)@\(host)" }
    var displayName: String { name.isEmpty ? sshTarget : name }
    /// 下拉/列表里的副标题。
    var subtitle: String {
        var s = sshTarget
        if port != 22 { s += ":\(port)" }
        s += usePassword ? L("  · 密码", "  · password") : L("  · 免密", "  · key/agent")
        return s
    }
}

// MARK: - 隧道

/// 单条隧道的持久化配置。引用一台 ServerConfig。
struct TunnelConfig: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var direction: Direction
    var serverID: UUID?
    /// 本机一侧的端口。
    var localPort: Int
    /// 云服务器一侧的端口。
    var remotePort: Int
    /// 备注：这条隧道是干啥的。
    var note: String = ""
    /// App 启动时是否自动拉起此隧道。
    var autoStart: Bool = false

    // 旧版本字段，仅用于迁移到 serverID。
    var legacyHost: String = ""
    var legacyUser: String = ""

    private enum CodingKeys: String, CodingKey {
        case id, name, direction, serverID, localPort, remotePort, note, autoStart
        case host, user   // legacy
    }
    init(id: UUID = UUID(), name: String, direction: Direction, serverID: UUID?,
         localPort: Int, remotePort: Int, note: String = "", autoStart: Bool = false) {
        self.id = id; self.name = name; self.direction = direction; self.serverID = serverID
        self.localPort = localPort; self.remotePort = remotePort
        self.note = note; self.autoStart = autoStart
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        direction = try c.decode(Direction.self, forKey: .direction)
        serverID = try c.decodeIfPresent(UUID.self, forKey: .serverID)
        localPort = try c.decode(Int.self, forKey: .localPort)
        remotePort = try c.decode(Int.self, forKey: .remotePort)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        autoStart = try c.decodeIfPresent(Bool.self, forKey: .autoStart) ?? false
        legacyHost = try c.decodeIfPresent(String.self, forKey: .host) ?? ""
        legacyUser = try c.decodeIfPresent(String.self, forKey: .user) ?? ""
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(direction, forKey: .direction)
        try c.encodeIfPresent(serverID, forKey: .serverID)
        try c.encode(localPort, forKey: .localPort)
        try c.encode(remotePort, forKey: .remotePort)
        try c.encode(note, forKey: .note)
        try c.encode(autoStart, forKey: .autoStart)
    }

    /// 端口转发参数（与服务器无关）。
    var forwardSpec: (flag: String, value: String) {
        switch direction {
        case .forward: return ("-L", "127.0.0.1:\(localPort):127.0.0.1:\(remotePort)")
        case .reverse: return ("-R", "127.0.0.1:\(remotePort):127.0.0.1:\(localPort)")
        }
    }

    /// 给用户看的地址描述。
    var addressLabel: String {
        switch direction {
        case .forward:  return "127.0.0.1:\(localPort)"
        case .reverse:  return remotePort == localPort ? "\(remotePort)" : "\(remotePort)"
        }
    }

    /// 菜单里那行右侧的明细：地址 + 服务器。
    func menuDetail(server: ServerConfig?) -> String {
        let s = server?.displayName ?? L("（缺服务器）", "(no server)")
        switch direction {
        case .forward:  return "127.0.0.1:\(localPort)  ·  \(s)"
        case .reverse:  return "\(s):\(remotePort)"
        }
    }

    /// 复制用的访问地址。
    func copyAddress(server: ServerConfig?) -> String {
        switch direction {
        case .forward:  return "127.0.0.1:\(localPort)"
        case .reverse:  return "\(server?.host ?? ""):\(remotePort)"
        }
    }

    /// 命令预览。
    func previewCommand(server: ServerConfig?) -> String {
        guard let server else { return L("（请先选择服务器）", "(select a server first)") }
        var parts = ["ssh", "-N"]
        if server.port != 22 { parts += ["-p", "\(server.port)"] }
        let spec = forwardSpec
        parts += [spec.flag, spec.value, server.sshTarget]
        let cmd = parts.joined(separator: " ")
        return server.usePassword ? L("（密码登录）", "(password) ") + cmd : cmd
    }
}

/// 隧道运行态。
enum TunnelStatus {
    case stopped, connecting, connected, reconnecting, error
    var dot: String {
        switch self {
        case .stopped:      return "⚪️"
        case .connecting:   return "🟡"
        case .connected:    return "🟢"
        case .reconnecting: return "🟠"
        case .error:        return "🔴"
        }
    }
}
