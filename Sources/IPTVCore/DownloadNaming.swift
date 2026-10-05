import Foundation

public enum DownloadNaming {
    /// A safe, unused file name "<title>.<ext>" ("<title> (2).<ext>" when taken). `taken` answers whether a name exists.
    public static func fileName(title: String, ext: String?, taken: (String) -> Bool) -> String {
        let bad = CharacterSet(charactersIn: "/\\:?*\"<>|").union(.controlCharacters)
        var base = title.components(separatedBy: bad).joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: ". ").union(.whitespacesAndNewlines))
        if base.isEmpty { base = "download" }
        base = String(base.prefix(120))
        let e = (ext ?? "").lowercased()
        let suffix = !e.isEmpty && e.count <= 5 && e.allSatisfy({ $0.isLetter || $0.isNumber }) ? e : "mp4"
        var name = "\(base).\(suffix)", n = 2
        while taken(name) { name = "\(base) (\(n)).\(suffix)"; n += 1 }
        return name
    }
}
