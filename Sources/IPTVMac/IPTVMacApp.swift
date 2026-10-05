import SwiftUI
import AppKit

@main
struct IPTVMacApp: App {
    @State private var model = AppModel()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        URLCache.shared = URLCache(memoryCapacity: 64 << 20, diskCapacity: 512 << 20)
    }

    var body: some Scene {
        WindowGroup {
            RootView().environment(model).frame(minWidth: 960, minHeight: 600).task { await model.start() }
        }
        Settings { SettingsView().environment(model) }
    }
}
