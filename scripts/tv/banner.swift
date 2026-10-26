// Draws the Android TV launcher banner (320x180 dp = 640x360 px at xhdpi) from the app icon.
// Run: swift scripts/tv/banner.swift   (writes flutter/android/app/src/main/res/drawable-xhdpi/tv_banner.png)
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let icon = NSImage(contentsOf: root.appendingPathComponent("docs/logo.png"))!
let w = 640, h = 360
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let bg = NSGradient(colors: [NSColor(red: 0.07, green: 0.08, blue: 0.20, alpha: 1), NSColor(red: 0.27, green: 0.33, blue: 0.87, alpha: 1)])!
bg.draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: 35)
icon.draw(in: NSRect(x: 70, y: 100, width: 160, height: 160))
let style = NSMutableParagraphStyle(); style.alignment = .left
let title = NSAttributedString(string: "IPTVMac", attributes: [.font: NSFont.systemFont(ofSize: 64, weight: .bold), .foregroundColor: NSColor.white, .paragraphStyle: style])
title.draw(at: NSPoint(x: 260, y: 158))
let sub = NSAttributedString(string: "IPTV player", attributes: [.font: NSFont.systemFont(ofSize: 30, weight: .regular), .foregroundColor: NSColor(white: 1, alpha: 0.82)])
sub.draw(at: NSPoint(x: 262, y: 118))
NSGraphicsContext.restoreGraphicsState()
let out = root.appendingPathComponent("flutter/android/app/src/main/res/drawable-xhdpi/tv_banner.png")
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("wrote \(out.path)")
