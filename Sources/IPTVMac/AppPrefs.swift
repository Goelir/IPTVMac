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
    /// Each language by its own name. A new language needs `Resources/<code>.lproj/Localizable.strings` and a row here
    /// (scripts/check-strings.py and a test check the keys).
    static let all: [(code: String, name: String)] = [
        ("he", "עברית"), ("en", "English"), ("ar", "العربية"), ("es", "Español"), ("fr", "Français"), ("de", "Deutsch"),
        ("pt", "Português"), ("it", "Italiano"), ("ru", "Русский"), ("uk", "Українська"), ("pl", "Polski"), ("ro", "Română"),
        ("bg", "Български"), ("nl", "Nederlands"), ("sv", "Svenska"), ("cs", "Čeština"), ("hu", "Magyar"), ("el", "Ελληνικά"),
        ("sq", "Shqip"), ("tr", "Türkçe"), ("fa", "فارسی"), ("ur", "اردو"), ("hi", "हिन्दी"), ("bn", "বাংলা"), ("id", "Bahasa Indonesia"),
        ("vi", "Tiếng Việt"), ("th", "ไทย"), ("zh-Hans", "简体中文"), ("zh-Hant", "繁體中文"), ("ja", "日本語"), ("ko", "한국어"),
    ]
    static var codes: [String] { all.map(\.code) }

    /// "system" unless this app's domain overrides it (the global value is the system's own list and must not count).
    static var current: String {
        let own = Bundle.main.bundleIdentifier.flatMap { UserDefaults.standard.persistentDomain(forName: $0)?["AppleLanguages"] as? [String] }
        guard let v = own?.first else { return "system" }
        return codes.first { v == $0 || v.hasPrefix($0 + "-") } ?? "system"   // "he-IL" -> "he", "zh-Hans-CN" -> "zh-Hans"
    }

    static func set(_ code: String) {
        if codes.contains(code) { UserDefaults.standard.set([code], forKey: "AppleLanguages") }
        else { UserDefaults.standard.removeObject(forKey: "AppleLanguages") }
    }
}
