import Foundation
import Network

/// 每条隧道的运行时状态（不持久化）。
private final class Runtime {
    var desiredOn = false
    var process: Process?
    var status: TunnelStatus = .stopped
    var attempt = 0
    var lastError: String = ""
    var logLines: [String] = []
    var reconnectWork: DispatchWorkItem?
}

/// 负责隧道配置持久化、ssh 进程生命周期、自动重连、健康探测。
final class TunnelManager {
    static let sshPath = "/usr/bin/ssh"
    static let expectPath = "/usr/bin/expect"

    let servers: ServerStore
    private(set) var tunnels: [TunnelConfig] = []
    private var runtimes: [UUID: Runtime] = [:]

    var onChange: (() -> Void)?

    private let configURL: URL
    private let probeQueue = DispatchQueue(label: "cloudtunnel.probe")
    private var healthTimer: Timer?

    init(servers: ServerStore) {
        self.servers = servers
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CloudTunnel", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        configURL = base.appendingPathComponent("tunnels.json")
        load()
    }

    // MARK: - 持久化 + 迁移

    private func load() {
        if let data = try? Data(contentsOf: configURL),
           let decoded = try? JSONDecoder().decode([TunnelConfig].self, from: data) {
            tunnels = decoded
            migrateLegacy()
        } else {
            tunnels = seedTunnels()
            save()
        }
    }

    /// 老配置只有 host/user，没有 serverID：迁移成引用 ServerStore 里的服务器。
    private func migrateLegacy() {
        var changed = false
        for i in tunnels.indices where tunnels[i].serverID == nil && !tunnels[i].legacyHost.isEmpty {
            let host = tunnels[i].legacyHost, user = tunnels[i].legacyUser
            let server = servers.server(host: host, user: user)
                ?? servers.add(ServerConfig(name: host, host: host, user: user), password: nil)
            tunnels[i].serverID = server.id
            changed = true
        }
        if changed { save() }
    }

    private func save() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(tunnels) { try? data.write(to: configURL, options: .atomic) }
    }

    private func seedTunnels() -> [TunnelConfig] {
        let sid = servers.server(host: "vps-jd", user: "")?.id ?? servers.servers.first?.id
        return [
            TunnelConfig(name: "服务器 11812", direction: .forward, serverID: sid,
                         localPort: 11812, remotePort: 11812, note: "测试：本地访问云上 11812"),
            TunnelConfig(name: "本地 5030 → 云", direction: .reverse, serverID: sid,
                         localPort: 5030, remotePort: 5030, note: "测试：云访问本机 5030"),
        ]
    }

    // MARK: - 查询

    func status(of id: UUID) -> TunnelStatus { runtimes[id]?.status ?? .stopped }
    func isOn(_ id: UUID) -> Bool { runtimes[id]?.desiredOn ?? false }
    func logs(of id: UUID) -> [String] { runtimes[id]?.logLines ?? [] }
    func config(for id: UUID) -> TunnelConfig? { tunnels.first { $0.id == id } }
    func server(for tunnelID: UUID) -> ServerConfig? { servers.server(for: config(for: tunnelID)?.serverID) }

    private func runtime(for id: UUID) -> Runtime {
        if let r = runtimes[id] { return r }
        let r = Runtime(); runtimes[id] = r; return r
    }

    // MARK: - 增删改

    func add(_ config: TunnelConfig) {
        tunnels.append(config); save(); notify()
        if config.autoStart { start(config.id) }
    }

    func update(_ config: TunnelConfig) {
        guard let idx = tunnels.firstIndex(where: { $0.id == config.id }) else { return }
        let wasOn = isOn(config.id)
        if wasOn { stop(config.id) }
        tunnels[idx] = config; save(); notify()
        if wasOn { start(config.id) }
    }

    func remove(_ id: UUID) {
        stop(id); tunnels.removeAll { $0.id == id }; runtimes[id] = nil; save(); notify()
    }

    // MARK: - 开关

    func toggle(_ id: UUID) { isOn(id) ? stop(id) : start(id) }

    func start(_ id: UUID) {
        guard let cfg = config(for: id) else { return }
        let rt = runtime(for: id)
        rt.desiredOn = true; rt.attempt = 0
        spawn(cfg)
    }

    func stop(_ id: UUID) {
        let rt = runtime(for: id)
        rt.desiredOn = false
        rt.reconnectWork?.cancel(); rt.reconnectWork = nil
        if let p = rt.process, p.isRunning { p.terminationHandler = nil; p.terminate() }
        rt.process = nil
        setStatus(id, .stopped)
    }

    func startAll() { tunnels.forEach { start($0.id) } }
    func stopAll()  { tunnels.forEach { stop($0.id) } }
    func startAutoStartTunnels() { tunnels.filter { $0.autoStart }.forEach { start($0.id) } }

    // MARK: - ssh 参数

    private func sshArgs(_ cfg: TunnelConfig, _ server: ServerConfig) -> [String] {
        var a = ["-N",
                 "-o", "ExitOnForwardFailure=yes",
                 "-o", "ServerAliveInterval=15",
                 "-o", "ServerAliveCountMax=3"]
        if server.usePassword {
            a += ["-o", "StrictHostKeyChecking=accept-new",
                  "-o", "NumberOfPasswordPrompts=1",
                  "-o", "PreferredAuthentications=password,keyboard-interactive"]
        } else {
            a += ["-o", "BatchMode=yes"]
        }
        if server.port != 22 { a += ["-p", "\(server.port)"] }
        let spec = cfg.forwardSpec
        a += [spec.flag, spec.value, server.sshTarget]
        return a
    }

    // MARK: - 进程

    private func spawn(_ cfg: TunnelConfig) {
        let rt = runtime(for: cfg.id)
        guard rt.desiredOn else { return }

        guard let server = servers.server(for: cfg.serverID) else {
            appendLog(cfg.id, "未配置服务器，无法启动")
            rt.desiredOn = false; setStatus(cfg.id, .error); return
        }

        let proc = Process()
        let args = sshArgs(cfg, server)

        if server.usePassword {
            guard let pw = Keychain.password(for: server.id) else {
                appendLog(cfg.id, "服务器「\(server.displayName)」缺少密码")
                rt.desiredOn = false; setStatus(cfg.id, .error); return
            }
            proc.executableURL = URL(fileURLWithPath: TunnelManager.expectPath)
            proc.arguments = ["-c", expectScript(sshArgs: args)]
            var env = ProcessInfo.processInfo.environment
            env["PASS"] = pw
            proc.environment = env
            appendLog(cfg.id, "$ ssh \(args.joined(separator: " "))  （密码登录）")
        } else {
            proc.executableURL = URL(fileURLWithPath: TunnelManager.sshPath)
            proc.arguments = args
            appendLog(cfg.id, "$ ssh \(args.joined(separator: " "))")
        }

        let errPipe = Pipe()
        proc.standardError = errPipe
        proc.standardOutput = Pipe()
        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let line = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.appendLog(cfg.id, line) }
        }
        proc.terminationHandler = { [weak self] p in
            errPipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async { self?.handleTermination(cfg.id, status: p.terminationStatus) }
        }

        do {
            try proc.run()
            rt.process = proc
            setStatus(cfg.id, .connecting)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self, let r = self.runtimes[cfg.id], r.desiredOn,
                      let p = r.process, p.isRunning else { return }
                r.attempt = 0
                self.setStatus(cfg.id, .connected)
                self.probeIfNeeded(cfg)
            }
        } catch {
            appendLog(cfg.id, "启动失败: \(error.localizedDescription)")
            rt.lastError = error.localizedDescription
            setStatus(cfg.id, .error)
        }
    }

    /// 用 expect 自动应答密码（密码从环境变量 PASS 取，不进 argv）。
    private func expectScript(sshArgs: [String]) -> String {
        let spawnLine = "spawn ssh " + sshArgs.joined(separator: " ")
        return """
        set timeout 30
        \(spawnLine)
        expect {
            -nocase -re "password:" { send -- "$env(PASS)\\r" }
            -nocase -re "passphrase" { send -- "$env(PASS)\\r" }
            timeout { exit 1 }
            eof { exit 1 }
        }
        interact
        """
    }

    private func handleTermination(_ id: UUID, status: Int32) {
        guard let rt = runtimes[id] else { return }
        rt.process = nil
        appendLog(id, "进程退出 (code=\(status))")
        guard rt.desiredOn else { setStatus(id, .stopped); return }

        rt.attempt += 1
        setStatus(id, .reconnecting)
        let delays: [Double] = [2, 5, 10, 30]
        let delay = delays[min(rt.attempt - 1, delays.count - 1)]
        appendLog(id, "\(Int(delay))s 后重连 (第 \(rt.attempt) 次)…")
        let work = DispatchWorkItem { [weak self] in
            guard let self, let cfg = self.config(for: id) else { return }
            self.spawn(cfg)
        }
        rt.reconnectWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    // MARK: - 健康探测

    func startHealthChecks() {
        healthTimer?.invalidate()
        healthTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: true) { [weak self] _ in
            guard let self else { return }
            for cfg in self.tunnels where self.runtimes[cfg.id]?.status == .connected {
                self.probeIfNeeded(cfg)
            }
        }
    }

    private func probeIfNeeded(_ cfg: TunnelConfig) {
        guard cfg.direction == .forward else { return }
        probeTCP(port: UInt16(cfg.localPort)) { [weak self] ok in
            DispatchQueue.main.async {
                guard let self, let rt = self.runtimes[cfg.id], rt.desiredOn,
                      let p = rt.process, p.isRunning else { return }
                self.setStatus(cfg.id, ok ? .connected : .connecting)
            }
        }
    }

    private func probeTCP(port: UInt16, completion: @escaping (Bool) -> Void) {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { completion(false); return }
        let conn = NWConnection(host: "127.0.0.1", port: nwPort, using: .tcp)
        var finished = false
        let finish: (Bool) -> Void = { ok in
            if finished { return }; finished = true; conn.cancel(); completion(ok)
        }
        conn.stateUpdateHandler = { state in
            switch state {
            case .ready: finish(true)
            case .failed, .cancelled: finish(false)
            default: break
            }
        }
        conn.start(queue: probeQueue)
        probeQueue.asyncAfter(deadline: .now() + 1.5) { finish(false) }
    }

    // MARK: - 工具

    private func setStatus(_ id: UUID, _ s: TunnelStatus) { runtime(for: id).status = s; notify() }

    private func appendLog(_ id: UUID, _ line: String) {
        let rt = runtime(for: id)
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let stamp = TunnelManager.timeFormatter.string(from: Date())
        for l in trimmed.split(separator: "\n") { rt.logLines.append("[\(stamp)] \(l)") }
        if rt.logLines.count > 200 { rt.logLines.removeFirst(rt.logLines.count - 200) }
    }

    private func notify() {
        if Thread.isMainThread { onChange?() }
        else { DispatchQueue.main.async { [weak self] in self?.onChange?() } }
    }

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f
    }()

    var anyRunning: Bool {
        tunnels.contains {
            let s = status(of: $0.id)
            return s == .connected || s == .connecting || s == .reconnecting
        }
    }
}
