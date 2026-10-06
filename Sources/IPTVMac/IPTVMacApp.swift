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
