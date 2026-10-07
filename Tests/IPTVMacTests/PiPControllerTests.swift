import AppKit
import Testing
import Foundation
@testable import IPTVMac

/// SwiftUI's NSHostingView used to overwrite the panel's size limits with its own content's minimum (0 x 28 without the
/// hover controls), so dragging a corner could shrink the floating video window to a sliver ("it disappears").
@MainActor @Test func pipPanelKeepsItsMinimumSize() async throws {
    _ = NSApplication.shared
    let pm = PlayerModel(request: PlayRequest(title: "t", url: URL(fileURLWithPath: "/nonexistent/none.mkv"), isLive: false, item: nil))
    defer { pm.close() }
    let c = PiPController(model: pm, title: "t", onReturn: {}, onClose: {})
    defer { c.dismiss() }
    c.panel.alphaValue = 0          // laid out and "shown" for SwiftUI, but not visible
    c.show()
    try await Task.sleep(for: .milliseconds(500))
    #expect(c.panel.minSize.width >= 240 && c.panel.minSize.height >= 135, "min size is \(c.panel.minSize)")
}
