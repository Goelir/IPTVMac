import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    nonisolated(unsafe) static var onQuit: (() -> Void)?
    nonisolated(unsafe) static var onReopen: (() -> Void)?
    func applicationWillTerminate(_ notification: Notification) { AppDelegate.onQuit?() }
    /// Dock icon clicked (or the app opened again): SwiftUI does not bring a closed window back by itself. `flag` is ignored,
    /// the floating PiP panel counts as a visible window while the main one is gone.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AppDelegate.onReopen?()
        return false
    }
}

/// Reports the window that hosts the view: the model needs the main window itself, not a guess from NSApp.windows.
private struct WindowReader: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void
    func makeNSView(context: Context) -> NSView { Hook(onWindow) }
    func updateNSView(_ v: NSView, context: Context) {}
    final class Hook: NSView {
        let onWindow: (NSWindow) -> Void
        init(_ f: @escaping (NSWindow) -> Void) { onWindow = f; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError() }
        override func viewDidMoveToWindow() { if let w = window { onWindow(w) } }
    }
}

private struct MainWindow: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        RootView().environment(model).frame(minWidth: 960, minHeight: 600)
            .background(WindowReader { model.attach($0) })
            .task {
                model.openMainWindow = { openWindow(id: "main") }
                AppDelegate.onReopen = { [model] in MainActor.assumeIsolated { model.showMainWindow() } }
                AppDelegate.onQuit = { [model] in
                    MainActor.assumeIsolated {
                        model.player?.close()                 // saves the resume point and stops mpv/GL cleanly before the process exits
                        model.applyStagedUpdateOnQuit()
                    }
                }
                await model.start()
            }
    }
}

@main
struct IPTVMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model: AppModel

    /// Versions up to 0.3.5 used the placeholder bundle id com.example.IPTVMac (it could collide with any other app using it).
    /// Settings (download folder, language preferences, toggles) are copied once from the old preferences domain.
    private static func migrateOldPreferences() {
        let old = "com.example.IPTVMac", d = UserDefaults.standard
        guard Bundle.main.bundleIdentifier != old, d.object(forKey: "migratedFromPlaceholderId") == nil else { return }
        for (k, v) in d.persistentDomain(forName: old) ?? [:] where d.object(forKey: k) == nil { d.set(v, forKey: k) }
        d.set(true, forKey: "migratedFromPlaceholderId")
    }

    init() {
        Self.migrateOldPreferences()
        // The self test must not open (and migrate) the user's real database first, so the model is created after it.
        if CommandLine.arguments.contains("--selftest") { SelfTest.run() }
        _model = State(initialValue: AppModel())
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        URLCache.shared = URLCache(memoryCapacity: 64 << 20, diskCapacity: 512 << 20)
    }

    var body: some Scene {
        WindowGroup(id: "main") { MainWindow(model: model) }
        // One window only (a second would fight the first for the single video view): File > Show Window brings it back, even after a close.
        .commands { CommandGroup(replacing: .newItem) { Button(L("menu.showWindow")) { model.showMainWindow() }.keyboardShortcut("n") } }
        Settings { SettingsView().environment(model) }
    }
}
