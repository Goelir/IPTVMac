import SwiftUI
import AppKit

/// Always-on-top mini window that hosts the player's video view (Picture-in-Picture).
@MainActor
final class PiPController: NSObject, NSWindowDelegate {
    let panel: NSPanel
    private let onClose: () -> Void
    private var closing = false

    init(model: PlayerModel, title: String, onReturn: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.onClose = onClose
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 480, height: 270),
                        styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        super.init()
        panel.title = title
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.contentAspectRatio = NSSize(width: 16, height: 9)
        panel.minSize = NSSize(width: 240, height: 135)
        panel.delegate = self
        // The SwiftUI hosting view must not be the window's content view: there it keeps overwriting the window's min/max size with its
        // content's (0 x 28, or 55 x 97 with the controls showing), so dragging a corner shrank the video window to a sliver.
        let host = NSHostingView(rootView: PiPView(model: model, onReturn: onReturn, onClose: { [weak self] in
            self?.dismiss(); onClose()
        }))
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 270))
        host.frame = content.bounds
        host.autoresizingMask = [.width, .height]
        content.addSubview(host)
        panel.contentView = content
    }

    func show() {
        if let f = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: f.maxX - panel.frame.width - 24, y: f.minY + 24))
        }
        panel.orderFrontRegardless()
    }

    /// Closes the panel without triggering `onClose` (used when returning to the main window).
    func dismiss() { closing = true; panel.close() }

    func windowWillClose(_ n: Notification) {
        guard !closing else { return }
        closing = true
        onClose()
    }
}

struct PiPView: View {
    let model: PlayerModel
    let onReturn: () -> Void
    let onClose: () -> Void
    @State private var hover = false

    var body: some View {
        ZStack {
            Color.black.allowsHitTesting(false)   // SwiftUI content that takes presses stops the panel's background drag
            PlayerSurface(model: model)
            if hover {
                VStack {
                    HStack {
                        Button(action: onClose) { Image(systemName: "xmark.circle.fill") }.help(L("player.close"))
                        Spacer()
                        Button(action: onReturn) { Image(systemName: "arrow.up.left.and.arrow.down.right") }.help(L("player.pipReturn"))
                    }.padding(8)
                    Spacer()
                    Button { model.mpv.togglePause() } label: { Image(systemName: model.paused ? "play.fill" : "pause.fill").font(.title) }
                    Spacer()
                }
                // The dimming must not take presses: only the buttons do, so a press anywhere else reaches the video and moves the window.
                .buttonStyle(.plain).foregroundStyle(.white).background { Color.black.opacity(0.35).allowsHitTesting(false) }
            }
        }
        .onHover { hover = $0 }
        .ignoresSafeArea()
    }
}
