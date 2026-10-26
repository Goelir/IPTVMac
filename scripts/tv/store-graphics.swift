// Draws the store graphics for the Android TV releases (Google Play and Amazon Appstore) into appstore/android-tv/graphics/.
// Run: swift scripts/tv/store-graphics.swift      (no window opens, it only writes PNG files)
// The icon is drawn from the same vector shapes as scripts/icon/icon.swift (docs/logo.png is only 256 px, too small to enlarge to 512), the look is that of scripts/tv/banner.swift.
// Files: play-icon-512.png (32-bit, Google Play app icon), play-feature-graphic-1024x500.png and play-tv-banner-1280x720.png (24-bit, NO alpha: Play rejects alpha there),
//        amazon-icon-114.png, amazon-icon-512.png.
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let outDir = root.appendingPathComponent("appstore/android-tv/graphics")
try! FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: a)
}

/// The app icon in `rect` (the 824-unit body of icon.swift scaled to rect). `radius` 0 = full-bleed square (what the stores want, they round it themselves).
func glyph(in rect: NSRect, radius: CGFloat) {
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.saveGState()
    if radius > 0 { NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip() } else { NSBezierPath(rect: rect).addClip() }
    ctx.translateBy(x: rect.minX, y: rect.minY); ctx.scaleBy(x: rect.width / 824, y: rect.height / 824); ctx.translateBy(x: -100, y: -100)
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    NSGradient(colors: [color(0x2563EB), color(0x6D28D9)])!.draw(in: body, angle: -55)
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!.draw(in: NSRect(x: 100, y: 520, width: 824, height: 404), angle: -90)
    let screen = NSRect(x: 222, y: 400, width: 580, height: 380)
    color(0x0B1020, 0.28).setFill()
    NSBezierPath(roundedRect: screen.offsetBy(dx: 0, dy: -10), xRadius: 78, yRadius: 78).fill()
    NSColor.white.setFill()
    NSBezierPath(roundedRect: screen, xRadius: 78, yRadius: 78).fill()
    NSBezierPath(roundedRect: NSRect(x: 452, y: 352, width: 120, height: 56), xRadius: 14, yRadius: 14).fill()
    NSBezierPath(roundedRect: NSRect(x: 352, y: 318, width: 320, height: 46), xRadius: 23, yRadius: 23).fill()
    let tri = NSBezierPath()
    tri.move(to: NSPoint(x: 458, y: 484)); tri.line(to: NSPoint(x: 458, y: 696)); tri.line(to: NSPoint(x: 650, y: 590)); tri.close()
    tri.lineJoinStyle = .round; tri.lineWidth = 34
    color(0x5B3DE0).setFill(); tri.fill(); color(0x5B3DE0).setStroke(); tri.stroke()
    ctx.restoreGState()
}

/// Same background as scripts/tv/banner.swift.
func background(_ w: Int, _ h: Int) {
    NSGradient(colors: [NSColor(red: 0.07, green: 0.08, blue: 0.20, alpha: 1), NSColor(red: 0.27, green: 0.33, blue: 0.87, alpha: 1)])!
        .draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: 35)
}

func text(_ s: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat = 1, at p: NSPoint) {
    NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: NSColor(white: 1, alpha: alpha)]).draw(at: p)
}

/// Renders a w x h image and writes a PNG; `alpha: false` writes a 24-bit PNG without an alpha channel.
func render(_ name: String, _ w: Int, _ h: Int, alpha: Bool, _ draw: () -> Void) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current!.imageInterpolation = .high
    draw()
    NSGraphicsContext.restoreGraphicsState()
    let url = outDir.appendingPathComponent(name)
    if alpha { try! rep.representation(using: .png, properties: [:])!.write(to: url) } else {
        // Re-encode through an opaque CGContext: ImageIO then writes a 24-bit PNG without an alpha channel.
        let cs = CGColorSpaceCreateDeviceRGB()
        let cg = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        cg.draw(rep.cgImage!, in: CGRect(x: 0, y: 0, width: w, height: h))
        let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, cg.makeImage()!, nil); precondition(CGImageDestinationFinalize(dest))
    }
    print("wrote \(name) \(w)x\(h)\(alpha ? "" : " (no alpha)")")
}

func tile(_ rect: NSRect) {             // rounded icon with a soft shadow, for the wide graphics
    NSGraphicsContext.saveGraphicsState()
    let sh = NSShadow(); sh.shadowColor = NSColor.black.withAlphaComponent(0.4); sh.shadowOffset = NSSize(width: 0, height: -rect.width * 0.03); sh.shadowBlurRadius = rect.width * 0.08; sh.set()
    color(0x1D4ED8).setFill(); NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225).fill()
    NSGraphicsContext.restoreGraphicsState()
    glyph(in: rect, radius: rect.width * 0.225)
}

// Icons: full-bleed squares.
for (name, px, alpha) in [("play-icon-512.png", 512, true), ("amazon-icon-512.png", 512, true), ("amazon-icon-114.png", 114, true)] {
    render(name, px, px, alpha: alpha) { glyph(in: NSRect(x: 0, y: 0, width: px, height: px), radius: 0) }
}

// Android TV banner 1280x720: icon, name, short line. Keep everything away from the edges (TVs crop).
render("play-tv-banner-1280x720.png", 1280, 720, alpha: false) {
    background(1280, 720)
    tile(NSRect(x: 170, y: 210, width: 300, height: 300))
    text("IPTVMac", size: 150, weight: .bold, at: NSPoint(x: 520, y: 330))
    text("IPTV player", size: 64, weight: .regular, alpha: 0.82, at: NSPoint(x: 526, y: 252))
}

// Feature graphic 1024x500 (Play shows it above the listing; keep the text in the middle third vertically).
render("play-feature-graphic-1024x500.png", 1024, 500, alpha: false) {
    background(1024, 500)
    tile(NSRect(x: 90, y: 140, width: 220, height: 220))
    text("IPTVMac", size: 104, weight: .bold, at: NSPoint(x: 345, y: 262))
    text("Your own IPTV, on the big screen", size: 36, weight: .regular, alpha: 0.88, at: NSPoint(x: 350, y: 205))
    text("Instant search  \u{00B7}  built-in player  \u{00B7}  31 languages", size: 26, weight: .regular, alpha: 0.7, at: NSPoint(x: 350, y: 160))
}
