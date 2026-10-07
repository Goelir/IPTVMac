import AppKit

/// Light/dark for the whole app. `NSApp.appearance` also covers Settings, sheets and the PiP panel; `.preferredColorScheme` does not.
enum Appearance {
    static func apply(_ choice: String?) {
        let a: NSAppearance? = switch choice { case "light": NSAppearance(named: .aqua); case "dark": NSAppearance(named: .darkAqua); default: nil }
        NSApplication.shared.appearance = a
    }
}

/// The interface language is this app's own `AppleLanguages` default, read by macOS at launch (RTL follows it).
/// To go back to the system language: pick System in Settings, or `defaults delete io.github.goelir.IPTVMac AppleLanguages`.
enum InterfaceLanguage {
    static let codes = ["he", "en", "ar"]

    /// "system" unless this app's domain overrides it (the global value is the system's own list and must not count).
    static var current: String {
        let own = Bundle.main.bundleIdentifier.flatMap { UserDefaults.standard.persistentDomain(forName: $0)?["AppleLanguages"] as? [String] }
        return own?.first.map { String($0.prefix { $0 != "-" }) }.flatMap { codes.contains($0) ? $0 : nil } ?? "system"   // "he-IL" -> "he"
    }

    static func set(_ code: String) {
        if codes.contains(code) { UserDefaults.standard.set([code], forKey: "AppleLanguages") }
        else { UserDefaults.standard.removeObject(forKey: "AppleLanguages") }
    }
}
