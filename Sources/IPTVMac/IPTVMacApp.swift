import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    nonisolated(unsafe) static var onQuit: (() -> Void)?
    func applicationWillTerminate(_ notification: Notification) { AppDelegate.onQuit?() }
}

@main
struct IPTVMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()

    init() {
        if CommandLine.arguments.contains("--selftest") { SelfTest.run() }
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        URLCache.shared = URLCache(memoryCapacity: 64 << 20, diskCapacity: 512 << 20)
    }

    var body: some Scene {
        WindowGroup {
            RootView().environment(model).frame(minWidth: 960, minHeight: 600).task {
                AppDelegate.onQuit = { [model] in MainActor.assumeIsolated { model.applyStagedUpdateOnQuit() } }
                await model.start()
            }
        }
        Settings { SettingsView().environment(model) }
    }
}
