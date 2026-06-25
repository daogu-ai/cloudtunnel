import AppKit
import SwiftUI
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private let serverStore = ServerStore()
    private lazy var manager = TunnelManager(servers: serverStore)
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var editWindow: NSWindow?
    private var serverWindow: NSWindow?

    /// 每条隧道在当前菜单里的各项引用，用于状态变化时就地刷新（菜单打开期间也实时生效）。
    private final class MenuRefs {
        var row: NSMenuItem?
        var toggleView: StayOpenItemView?
        var edit: NSMenuItem?
        var del: NSMenuItem?
    }
    private var menuRefs: [UUID: MenuRefs] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()   // 让编辑窗口里的 Cmd+C/V/X/A/Z 生效
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu

        manager.onChange = { [weak self] in self?.handleChange() }
        manager.startHealthChecks()
        manager.startAutoStartTunnels()
        updateIcon()
    }

    func applicationWillTerminate(_ notification: Notification) {
        manager.stopAll()
    }

    /// 菜单栏(.accessory)应用默认没有主菜单，导致输入框里 Cmd+C/V 等失效。
    /// 这里建一个标准"编辑"菜单，标准动作走响应链到当前聚焦的文本框。
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: L("退出 CloudTunnel", "Quit CloudTunnel"),
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: L("编辑", "Edit"))
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: L("撤销", "Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: L("重做", "Redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: L("剪切", "Cut"), action: Selector(("cut:")), keyEquivalent: "x")
        editMenu.addItem(withTitle: L("拷贝", "Copy"), action: Selector(("copy:")), keyEquivalent: "c")
        editMenu.addItem(withTitle: L("粘贴", "Paste"), action: Selector(("paste:")), keyEquivalent: "v")
        editMenu.addItem(withTitle: L("全选", "Select All"), action: Selector(("selectAll:")), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
    }

    // MARK: - 状态变化

    /// 状态变化时：刷新菜单栏图标，并就地更新每条隧道的状态点、开关文案、编辑/删除可用状态。
    /// 菜单打开期间也实时生效，无需重开菜单。
    private func handleChange() {
        updateIcon()
        for (id, refs) in menuRefs {
            let on = manager.isOn(id)
            if let row = refs.row { let t = rowTitle(id); if row.title != t { row.title = t } }
            refs.toggleView?.refresh()
            if let edit = refs.edit { edit.isEnabled = !on; edit.title = editTitle(on: on) }
            if let del = refs.del  { del.isEnabled = !on;  del.title = delTitle(on: on) }
        }
    }

    private func editTitle(on: Bool) -> String {
        on ? L("✎  编辑…（先停止）", "✎  Edit…  (stop first)") : L("✎  编辑…", "✎  Edit…")
    }
    private func delTitle(on: Bool) -> String {
        on ? L("🗑  删除（先停止）", "🗑  Delete  (stop first)") : L("🗑  删除", "🗑  Delete")
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let name = manager.anyRunning ? "arrow.up.arrow.down.circle.fill" : "arrow.up.arrow.down.circle"
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "CloudTunnel")
        img?.isTemplate = true
        button.image = img
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) { populate(menu) }

    // MARK: - 构建菜单

    private func rowTitle(_ id: UUID) -> String {
        guard let cfg = manager.config(for: id) else { return "" }
        return "  \(manager.status(of: id).dot)  \(cfg.name)   —   \(cfg.menuDetail(server: manager.server(for: id)))"
    }

    private func populate(_ menu: NSMenu) {
        menu.removeAllItems()
        menuRefs.removeAll()

        let label = serverStore.servers.isEmpty ? "CloudTunnel"
            : "CloudTunnel · " + serverStore.servers.map { $0.displayName }.joined(separator: ", ")
        addDisabled(label, to: menu)
        menu.addItem(.separator())

        addGroup(.forward, to: menu)
        addGroup(.reverse, to: menu)
        if manager.tunnels.isEmpty { addDisabled(L("暂无隧道，点下方新建", "No tunnels — create one below"), to: menu) }

        menu.addItem(.separator())
        addAction(L("＋ 新建隧道…", "＋ New Tunnel…"), #selector(newTunnel), to: menu, key: "n")
        addAction(L("🖥 服务器管理…", "🖥 Manage Servers…"), #selector(manageServers), to: menu)
        addAction(L("⟳ 全部重连", "⟳ Reconnect All"), #selector(startAll), to: menu)
        addAction(L("⏻ 全部停止", "⏻ Stop All"), #selector(stopAllAction), to: menu)

        menu.addItem(.separator())
        let login = NSMenuItem(title: L("登录时启动 CloudTunnel", "Launch CloudTunnel at Login"), action: #selector(toggleLoginItem), keyEquivalent: "")
        login.target = self
        login.state = loginItemEnabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        addAction(L("退出", "Quit"), #selector(quit), to: menu, key: "q")
    }

    private func addDisabled(_ title: String, to menu: NSMenu) {
        let it = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        it.isEnabled = false
        menu.addItem(it)
    }

    @discardableResult
    private func addAction(_ title: String, _ sel: Selector, to menu: NSMenu, key: String = "") -> NSMenuItem {
        let it = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        it.target = self
        menu.addItem(it)
        return it
    }

    private func addGroup(_ direction: Direction, to menu: NSMenu) {
        let items = manager.tunnels.filter { $0.direction == direction }
        guard !items.isEmpty else { return }

        addDisabled(direction.label, to: menu)

        // 每条隧道 = 带原生 ▸ 的标准项；点开子菜单，第一项即启动/停止。
        for cfg in items {
            let refs = MenuRefs()
            menuRefs[cfg.id] = refs
            let item = NSMenuItem(title: rowTitle(cfg.id), action: nil, keyEquivalent: "")
            item.submenu = managementMenu(for: cfg.id)   // 会填充 refs.toggleView/edit/del
            menu.addItem(item)
            refs.row = item
        }
    }

    /// 隧道的子菜单（第一项启动/停止 + 编辑/复制/删除）。
    private func managementMenu(for id: UUID) -> NSMenu {
        let sub = NSMenu()
        sub.autoenablesItems = false
        guard let cfg = manager.config(for: id) else { return sub }
        let on = manager.isOn(id)

        // 先建标准项（编辑/复制/删除 + 信息），便于量算子菜单宽度。
        if !cfg.note.isEmpty {
            let n = NSMenuItem(title: "📝  \(cfg.note)", action: nil, keyEquivalent: "")
            n.isEnabled = false
            sub.addItem(n)
        }
        let target = NSMenuItem(title: "🔗  \(cfg.menuDetail(server: manager.server(for: id)))", action: nil, keyEquivalent: "")
        target.isEnabled = false
        sub.addItem(target)
        sub.addItem(.separator())

        // 运行中禁止编辑/删除，必须先停止。
        let edit = NSMenuItem(title: editTitle(on: on), action: #selector(editTunnel(_:)), keyEquivalent: "")
        edit.target = self; edit.representedObject = id.uuidString
        edit.isEnabled = !on
        sub.addItem(edit)

        let copy = NSMenuItem(title: L("⧉  复制地址", "⧉  Copy Address"), action: #selector(copyAddress(_:)), keyEquivalent: "")
        copy.target = self; copy.representedObject = id.uuidString
        sub.addItem(copy)

        let del = NSMenuItem(title: delTitle(on: on), action: #selector(deleteTunnel(_:)), keyEquivalent: "")
        del.target = self; del.representedObject = id.uuidString
        del.isEnabled = !on
        sub.addItem(del)

        menuRefs[id]?.edit = edit
        menuRefs[id]?.del = del

        // 量算宽度，让常驻开关项与其它项一样宽（点哪都生效）。
        var maxW: CGFloat = 150
        for it in sub.items where !it.title.isEmpty {
            let w = (it.title as NSString).size(withAttributes: [.font: StayOpenItemView.font]).width + 52
            maxW = max(maxW, w)
        }

        // 顶部插入"常驻"开关项：点击只切换、不关闭菜单，可连续开关多个。
        let toggleView = StayOpenItemView(
            width: maxW,
            titleProvider: { [weak self] in
                (self?.manager.isOn(id) ?? false) ? L("⏸  停止", "⏸  Stop") : L("▶  启动", "▶  Start")
            },
            action: { [weak self] in self?.manager.toggle(id) }
        )
        let toggleItem = NSMenuItem()
        toggleItem.view = toggleView
        sub.insertItem(.separator(), at: 0)
        sub.insertItem(toggleItem, at: 0)
        menuRefs[id]?.toggleView = toggleView

        return sub
    }

    // MARK: - 动作

    private func id(from sender: Any?) -> UUID? {
        guard let s = (sender as? NSMenuItem)?.representedObject as? String else { return nil }
        return UUID(uuidString: s)
    }

    @objc private func toggleTunnel(_ sender: NSMenuItem) {
        guard let id = id(from: sender) else { return }
        manager.toggle(id)
    }

    @objc private func editTunnel(_ sender: NSMenuItem) {
        guard let id = id(from: sender), let cfg = manager.config(for: id) else { return }
        guard !manager.isOn(id) else { return }   // 运行中不可编辑
        showEditor(existing: cfg)
    }

    @objc private func copyAddress(_ sender: NSMenuItem) {
        guard let id = id(from: sender), let cfg = manager.config(for: id) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cfg.copyAddress(server: manager.server(for: id)), forType: .string)
    }

    @objc private func deleteTunnel(_ sender: NSMenuItem) {
        guard let id = id(from: sender), let cfg = manager.config(for: id) else { return }
        guard !manager.isOn(id) else { return }   // 运行中不可删除
        let alert = NSAlert()
        alert.messageText = L("删除隧道「\(cfg.name)」？", "Delete tunnel “\(cfg.name)”?")
        alert.informativeText = L("此操作不可撤销。", "This cannot be undone.")
        alert.addButton(withTitle: L("删除", "Delete"))
        alert.addButton(withTitle: L("取消", "Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            manager.remove(id)
        }
    }

    @objc private func newTunnel() { showEditor(existing: nil) }
    @objc private func startAll() { manager.startAll() }
    @objc private func stopAllAction() { manager.stopAll() }
    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: - 编辑窗口

    private func showEditor(existing: TunnelConfig?) {
        closeEditor()   // 全局只留一个编辑窗口，避免叠出多个
        let view = AddEditView(
            existing: existing,
            serverStore: serverStore,
            onSave: { [weak self] cfg in
                guard let self else { return }
                if existing == nil { self.manager.add(cfg) } else { self.manager.update(cfg) }
                self.closeEditor()
            },
            onDelete: existing == nil ? nil : { [weak self] id in
                self?.manager.remove(id)
                self?.closeEditor()
            },
            onCancel: { [weak self] in self?.closeEditor() },
            onManageServers: { [weak self] in self?.manageServers() }
        )

        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = existing == nil ? L("新建隧道", "New Tunnel") : L("编辑隧道", "Edit Tunnel")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        editWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func closeEditor() {
        editWindow?.delegate = nil
        editWindow?.close()
        editWindow = nil
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard let w = notification.object as? NSWindow else { return }
        if w == editWindow { editWindow = nil }
        if w == serverWindow { serverWindow = nil }
    }

    /// 点到别处 / 打开主菜单导致编辑窗口失去焦点 → 关闭它，避免遗留多个窗口。
    func windowDidResignKey(_ notification: Notification) {
        guard let w = notification.object as? NSWindow, w == editWindow else { return }
        w.close()
    }

    // MARK: - 服务器管理窗口

    @objc private func manageServers() {
        if let w = serverWindow {
            NSApp.activate(ignoringOtherApps: true)
            w.makeKeyAndOrderFront(nil)
            return
        }
        let view = ServerManagerView(store: serverStore) { [weak self] serverID in
            self?.manager.tunnels.filter { $0.serverID == serverID }.count ?? 0
        }
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = L("服务器管理", "Servers")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        serverWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - 开机自启 (SMAppService，需以打包 .app 运行)

    private var loginItemEnabled: Bool {
        if #available(macOS 13.0, *) { return SMAppService.mainApp.status == .enabled }
        return false
    }

    @objc private func toggleLoginItem() {
        guard #available(macOS 13.0, *) else { return }
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = L("设置开机自启失败", "Failed to set launch at login")
            alert.informativeText = L("需要以打包后的 CloudTunnel.app 运行（拖到 /Applications）。\n\n",
                                      "Run the bundled CloudTunnel.app (move it to /Applications).\n\n") + error.localizedDescription
            alert.runModal()
        }
    }
}
