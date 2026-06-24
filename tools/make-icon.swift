// 生成 CloudTunnel 的 App 图标（苹果风圆角方块 + 白色双向箭头）。
// 用法: swift tools/make-icon.swift <输出 iconset 目录>
// 之后: iconutil -c icns <iconset> -o Resources/AppIcon.icns
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dist/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func draw(_ s: CGFloat) {
    // 圆角方块（Big Sur 网格：内容约占 80%，连续圆角）
    let margin = s * 0.0977
    let rect = NSRect(x: margin, y: margin, width: s - 2*margin, height: s - 2*margin)
    let radius = rect.width * 0.2247
    let squircle = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    // 主体竖向渐变（克制的品牌蓝，低到中饱和）
    squircle.addClip()
    let top = NSColor(srgbRed: 0.29, green: 0.62, blue: 1.00, alpha: 1)   // #4A9EFF
    let bottom = NSColor(srgbRed: 0.05, green: 0.39, blue: 0.85, alpha: 1) // #0C63D9
    NSGradient(colors: [top, bottom])?.draw(in: squircle, angle: -90)

    // 顶部柔光，增加质感
    let sheen = NSGradient(colors: [NSColor(white: 1, alpha: 0.18), NSColor(white: 1, alpha: 0)])
    sheen?.draw(in: squircle, angle: -90)

    // 双向箭头（白色，圆角端点）
    let cx = s/2, cy = s/2
    let hh = s * 0.205          // 箭杆半高
    let off = s * 0.092         // 两箭距中心
    let hw = s * 0.058          // 箭头半宽
    let hp = s * 0.058          // 箭头高度
    let stroke = s * 0.062

    let xL = cx - off, xR = cx + off

    let up = NSBezierPath()      // 左：向上
    up.move(to: NSPoint(x: xL, y: cy - hh))
    up.line(to: NSPoint(x: xL, y: cy + hh))
    up.move(to: NSPoint(x: xL - hw, y: cy + hh - hp))
    up.line(to: NSPoint(x: xL, y: cy + hh))
    up.line(to: NSPoint(x: xL + hw, y: cy + hh - hp))

    let down = NSBezierPath()    // 右：向下
    down.move(to: NSPoint(x: xR, y: cy + hh))
    down.line(to: NSPoint(x: xR, y: cy - hh))
    down.move(to: NSPoint(x: xR - hw, y: cy - hh + hp))
    down.line(to: NSPoint(x: xR, y: cy - hh))
    down.line(to: NSPoint(x: xR + hw, y: cy - hh + hp))

    for p in [up, down] {
        p.lineWidth = stroke
        p.lineCapStyle = .round
        p.lineJoinStyle = .round
    }

    // 轻微投影做出层次
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(white: 0, alpha: 0.22)
    shadow.shadowOffset = NSSize(width: 0, height: -s*0.006)
    shadow.shadowBlurRadius = s * 0.012
    shadow.set()

    NSColor.white.setStroke()
    up.stroke(); down.stroke()
}

func render(px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.clear.set()
    NSRect(x: 0, y: 0, width: px, height: px).fill()
    draw(CGFloat(px))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// iconset 需要的命名与尺寸
let specs: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in specs {
    let data = render(px: px)
    let path = "\(outDir)/\(name).png"
    try! data.write(to: URL(fileURLWithPath: path))
    print("写出 \(path) (\(px)px)")
}
print("完成。")
