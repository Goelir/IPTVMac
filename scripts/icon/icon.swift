// Draws the app icon: swift scripts/icon/icon.swift out.png [pixels]
import AppKit

let out = CommandLine.arguments[1]
let px = Int(CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "1024") ?? 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let k = CGFloat(px) / 1024
let ctx = NSGraphicsContext.current!.cgContext
ctx.scaleBy(x: k, y: k)

func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: a)
}

// macOS icon grid: 824 x 824 body centred in the 1024 canvas, soft shadow below it.
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
shadow.shadowOffset = NSSize(width: 0, height: -14); shadow.shadowBlurRadius = 28; shadow.set()
color(0x1D4ED8).setFill(); bodyPath.fill()
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.saveGraphicsState()
bodyPath.addClip()
NSGradient(colors: [color(0x2563EB), color(0x6D28D9)])!.draw(in: body, angle: -55)
NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!
    .draw(in: NSRect(x: 100, y: 520, width: 824, height: 404), angle: -90)          // soft top highlight
NSGraphicsContext.restoreGraphicsState()

// TV: white screen, stand, and a play triangle cut in the gradient colour.
let screen = NSRect(x: 222, y: 400, width: 580, height: 380)
color(0x0B1020, 0.28).setFill()
NSBezierPath(roundedRect: screen.offsetBy(dx: 0, dy: -10), xRadius: 78, yRadius: 78).fill()
NSColor.white.setFill()
NSBezierPath(roundedRect: screen, xRadius: 78, yRadius: 78).fill()
NSBezierPath(roundedRect: NSRect(x: 452, y: 352, width: 120, height: 56), xRadius: 14, yRadius: 14).fill()          // neck
NSBezierPath(roundedRect: NSRect(x: 352, y: 318, width: 320, height: 46), xRadius: 23, yRadius: 23).fill()         // base

let tri = NSBezierPath()
tri.move(to: NSPoint(x: 458, y: 484)); tri.line(to: NSPoint(x: 458, y: 696)); tri.line(to: NSPoint(x: 650, y: 590)); tri.close()
tri.lineJoinStyle = .round; tri.lineWidth = 34
color(0x5B3DE0).setFill(); tri.fill()
color(0x5B3DE0).setStroke(); tri.stroke()      // the stroke rounds the corners
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
