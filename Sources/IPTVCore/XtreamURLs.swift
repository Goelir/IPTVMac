import Foundation

public struct XtreamURLs {
    let base: String, user: String, pass: String

    public init?(server: String, username: String, password: String) {
        var s = server.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if !s.lowercased().hasPrefix("http://") && !s.lowercased().hasPrefix("https://") { s = "http://" + s }
        guard var c = URLComponents(string: s), c.host?.isEmpty == false else { return nil }
        // Users paste whatever the provider showed: ".../get.php?username=..&password=.." or ".../player_api.php?..": keep the server only.
        c.query = nil; c.fragment = nil; c.user = nil; c.password = nil
        var path = c.path
        while path.hasSuffix("/") { path.removeLast() }
        for tail in ["/player_api.php", "/get.php", "/xmltv.php", "/panel_api.php", "/c"] where path.lowercased().hasSuffix(tail) {
            path = String(path.dropLast(tail.count)); break
        }
        c.path = path
        guard var b = c.string else { return nil }
        while b.hasSuffix("/") { b.removeLast() }
        base = b
        // A trailing space or newline pasted with the credentials would make a correct login look wrong.
        user = Self.enc(username.trimmingCharacters(in: .whitespacesAndNewlines))
        pass = Self.enc(password.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static let unreserved = CharacterSet(charactersIn:
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
    private static func enc(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: unreserved) ?? s }

    private func build(_ s: String) -> URL { URL(string: s)! }
    private func e(_ ext: String?) -> String { (ext?.isEmpty == false) ? ext! : "mp4" }

    public func live(id: String, ext: String = "ts") -> URL { build("\(base)/live/\(user)/\(pass)/\(id).\(ext)") }
    public func movie(id: String, ext: String?) -> URL { build("\(base)/movie/\(user)/\(pass)/\(id).\(e(ext))") }
    public func series(id: String, ext: String?) -> URL { build("\(base)/series/\(user)/\(pass)/\(id).\(e(ext))") }

    public func stream(type: ItemType, id: String, ext: String?) -> URL {
        switch type {
        case .live: return live(id: id)
        case .movie: return movie(id: id, ext: ext)
        case .series: return series(id: id, ext: ext)
        }
    }

    public func timeshift(id: String, start: Date, minutes: Int, timeZone: TimeZone = .current) -> URL {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = timeZone
        f.dateFormat = "yyyy-MM-dd:HH-mm"
        return build("\(base)/timeshift/\(user)/\(pass)/\(minutes)/\(f.string(from: start))/\(id).ts")
    }

    public func api(_ action: String?, _ params: [String: String] = [:]) -> URL {
        var q = "username=\(user)&password=\(pass)"
        if let action { q += "&action=\(action)" }
        for (k, v) in params.sorted(by: { $0.key < $1.key }) { q += "&\(k)=\(Self.enc(v))" }
        return build("\(base)/player_api.php?\(q)")
    }
}
