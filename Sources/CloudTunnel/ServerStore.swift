import Foundation
import Combine

/// 服务器配置的持久化（密码另存钥匙串）。
final class ServerStore: ObservableObject {
    @Published private(set) var servers: [ServerConfig] = []
    private let url: URL

    init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CloudTunnel", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        url = base.appendingPathComponent("servers.json")
        load()
    }

    private func load() {
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([ServerConfig].self, from: data) {
            servers = decoded
        } else {
            servers = [ServerConfig(name: "京东云", host: "vps-jd")]   // 首次预置一台免密服务器
            save()
        }
    }

    private func save() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(servers) { try? data.write(to: url, options: .atomic) }
    }

    func server(for id: UUID?) -> ServerConfig? {
        guard let id else { return nil }
        return servers.first { $0.id == id }
    }

    /// 按 host+user 找已有服务器（迁移老隧道用）。
    func server(host: String, user: String) -> ServerConfig? {
        servers.first { $0.host == host && $0.user == user }
    }

    @discardableResult
    func add(_ s: ServerConfig, password: String?) -> ServerConfig {
        servers.append(s)
        if s.usePassword, let password { Keychain.setPassword(password, for: s.id) }
        save()
        return s
    }

    func update(_ s: ServerConfig, password: String?) {
        guard let idx = servers.firstIndex(where: { $0.id == s.id }) else { return }
        servers[idx] = s
        if s.usePassword {
            if let password, !password.isEmpty { Keychain.setPassword(password, for: s.id) }
        } else {
            Keychain.delete(for: s.id)
        }
        save()
    }

    func remove(_ id: UUID) {
        servers.removeAll { $0.id == id }
        Keychain.delete(for: id)
        save()
    }
}
