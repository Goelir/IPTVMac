import Foundation

public enum DownloadNaming {
    static let videoExtensions: Set<String> = ["mp4", "mkv", "avi", "mov", "m4v", "ts", "webm", "flv", "wmv", "mpg", "mpeg", "m2ts", "mts", "3gp"]

    /// A safe, unused file name "<title>.<ext>" ("<title> (2).<ext>" when taken). `taken` answers whether a name exists.
    public static func fileName(title: String, ext: String?, taken: (String) -> Bool) -> String {
        let bad = CharacterSet(charactersIn: "/\\:?*\"<>|").union(.controlCharacters)
        var base = title.components(separatedBy: bad).joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: ". ").union(.whitespacesAndNewlines))
        if base.isEmpty { base = "download" }
        base = String(base.prefix(120))
        // The provider chooses the extension: only video containers, never .dmg/.pkg/.app/.sh/.zip that could open from Finder.
        let e = (ext ?? "").lowercased()
        let suffix = videoExtensions.contains(e) ? e : "mp4"
        // 255 bytes is the file name limit, and CJK/emoji take 3-4 bytes per character: keep room for " (99)" and the extension.
        while base.utf8.count > 200 { base.removeLast() }
        var name = "\(base).\(suffix)", n = 2
        while taken(name) { name = "\(base) (\(n)).\(suffix)"; n += 1 }
        return name
    }
}
