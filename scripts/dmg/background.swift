// Draws the DMG window background: swift scripts/dmg/background.swift out.png
import AppKit

let out = CommandLine.arguments[1]
let w = 660, h = 400, scale = 2
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w * scale, pixelsHigh: h * scale, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: w, height: h)          // 144 dpi: drawn at 660x400 points on Retina
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

NSGradient(starting: NSColor(calibratedWhite: 0.97, alpha: 1), ending: NSColor(calibratedWhite: 0.88, alpha: 1))!
    .draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: -90)

func text(_ s: String, size: CGFloat, y: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .darkGray) {
    let p = NSMutableParagraphStyle(); p.alignment = .center
    let a: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: p]
    NSAttributedString(string: s, attributes: a).draw(in: NSRect(x: 0, y: y, width: CGFloat(w), height: size + 10))
}
text("Drag IPTVMac to Applications", size: 22, y: 330, weight: .semibold, color: .black)
text("גרור את IPTVMac אל Applications", size: 18, y: 298)

// arrow between the two icons (icons sit at x=170 and x=490, y=200 from the top => 200 from the bottom)
let arrow = NSBezierPath()
arrow.lineWidth = 6; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: 250, y: 200)); arrow.line(to: NSPoint(x: 400, y: 200))
arrow.move(to: NSPoint(x: 370, y: 228)); arrow.line(to: NSPoint(x: 405, y: 200)); arrow.line(to: NSPoint(x: 370, y: 172))
NSColor(calibratedWhite: 0.45, alpha: 1).setStroke(); arrow.stroke()

text("First launch: System Settings > Privacy & Security > Open Anyway", size: 12, y: 40, color: .gray)
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
