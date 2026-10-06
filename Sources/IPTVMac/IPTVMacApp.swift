import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    nonisolated(unsafe) static var onQuit: (() -> Void)?
    func applicationWillTerminate(_ notification: Notification) { AppDelegate.onQuit?() }
}

@main
struct IPTVMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model: AppModel

    init() {
        // The self test must not open (and migrate) the user's real database first, so the model is created after it.
        if CommandLine.arguments.contains("--selftest") { SelfTest.run() }
        _model = State(initialValue: AppModel())
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        URLCache.shared = URLCache(memoryCapacity: 64 << 20, diskCapacity: 512 << 20)
    }

    var body: some Scene {
        WindowGroup {
            RootView().environment(model).frame(minWidth: 960, minHeight: 600).task {
                AppDelegate.onQuit = { [model] in
                    MainActor.assumeIsolated {
                        model.player?.close()                 // saves the resume point and stops mpv/GL cleanly before the process exits
                        model.applyStagedUpdateOnQuit()
                    }
                }
                await model.start()
            }
        }
        .commands { CommandGroup(replacing: .newItem) {} }   // a second window would fight the first for the single video view
        Settings { SettingsView().environment(model) }
    }
}
