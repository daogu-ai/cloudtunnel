import AppKit

/// 常驻菜单项：点击执行动作但**不关闭菜单**，用于"连续开关多个隧道"。
/// 整项只有一个动作（点哪都一样），规避了自绘行分区域命中的不可靠。
final class StayOpenItemView: NSView {
    static let font = NSFont.menuFont(ofSize: 0)
    private static let height: CGFloat = 22
    private static let textInset: CGFloat = 21   // 对齐标准菜单项文字起点

    private let titleProvider: () -> String
    private let action: () -> Void
    private var title: String
    private var inside = false

    init(width: CGFloat, titleProvider: @escaping () -> String, action: @escaping () -> Void) {
        self.titleProvider = titleProvider
        self.action = action
        self.title = titleProvider()
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: Self.height))
        autoresizingMask = [.width]
    }
    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }
    override func mouseEntered(with event: NSEvent) { inside = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent)  { inside = false; needsDisplay = true }

    override func draw(_ dirtyRect: NSRect) {
        let textColor: NSColor
        if inside {
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 1), xRadius: 5, yRadius: 5).fill()
            textColor = .white
        } else {
            textColor = .labelColor
        }
        let attrs: [NSAttributedString.Key: Any] = [.font: Self.font, .foregroundColor: textColor]
        let ns = title as NSString
        let size = ns.size(withAttributes: attrs)
        ns.draw(at: NSPoint(x: Self.textInset, y: (bounds.height - size.height) / 2), withAttributes: attrs)
    }

    override func mouseUp(with event: NSEvent) {
        action()
        refresh()
        // 不调用 cancelTracking —— 菜单保持打开，可继续切换其它隧道
    }

    /// 外部状态变化时刷新文案（启动 <-> 停止），菜单打开期间也实时生效。
    func refresh() {
        let t = titleProvider()
        if t != title { title = t; needsDisplay = true }
    }
}
