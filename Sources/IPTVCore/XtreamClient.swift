import Foundation

public enum IPTVError: Error, LocalizedError, Equatable {
    case http(Int), badResponse, badConfig, badCredentials, emptyResponse
    public var errorDescription: String? {
        switch self {
        case .http(let c): return "HTTP \(c)"
        case .badResponse: return "Unexpected response from server"
        case .badConfig: return "Invalid server address"
        case .badCredentials: return "Wrong username or password"
        case .emptyResponse: return "The server returned an empty list; keeping your saved data"
        }
    }
}

/// Session for Xtream/M3U requests. Their URLs contain the account password, so nothing may reach the on-disk URL cache.
public let apiSession: URLSession = {
    let c = URLSessionConfiguration.ephemeral
    c.urlCache = nil
    c.requestCachePolicy = .reloadIgnoringLocalCacheData
    return URLSession(configuration: c)
}()

public struct EPGEntry: Equatable {
    public var title: String, start: Date, end: Date
    public init(title: String, start: Date, end: Date) { self.title = title; self.start = start; self.end = end }
}

/// Xtream JSON is loosely typed (ids as string or number, null ratings), so we read it untyped.
func str(_ v: Any?) -> String? {
    switch v {
    case let s as String: return s.isEmpty ? nil : s
    case let n as NSNumber: return n.stringValue
    default: return nil
    }
}
func int(_ v: Any?) -> Int? { str(v).flatMap { Int($0) } }

public struct XtreamClient {
    let urls: XtreamURLs
    let session: URLSession
    public init(urls: XtreamURLs, session: URLSession = apiSession) { self.urls = urls; self.session = session }

    func json(_ url: URL) async throws -> Any {
        let (data, resp) = try await session.data(from: url)
        if let code = (resp as? HTTPURLResponse)?.statusCode, !(200..<300).contains(code) { throw IPTVError.http(code) }
        guard let obj = try? JSONSerialization.jsonObject(with: data) else { throw IPTVError.badResponse }
        return obj
    }

    func array(_ action: String, _ params: [String: String] = [:]) async throws -> [[String: Any]] {
        guard let a = try await json(urls.api(action, params)) as? [[String: Any]] else { throw IPTVError.badResponse }
        return a
    }

    public func authenticate() async throws {
        guard let o = try await json(urls.api(nil)) as? [String: Any], let u = o["user_info"] as? [String: Any]
        else { throw IPTVError.badResponse }
        if int(u["auth"]) != 1 { throw IPTVError.badCredentials }
    }

    /// Timezone the panel uses for timeshift URLs (`server_info.timezone`), or nil if unknown.
    public func serverTimeZone() async -> TimeZone? {
        guard let o = try? await json(urls.api(nil)) as? [String: Any],
              let info = o["server_info"] as? [String: Any], let id = str(info["timezone"]) else { return nil }
        return TimeZone(identifier: id)
    }

    private func listings(_ action: String, _ id: String, _ extra: [String: String] = [:]) async throws -> [[String: Any]] {
        var p = ["stream_id": id]; p.merge(extra) { $1 }
        guard let o = try await json(urls.api(action, p)) as? [String: Any] else { throw IPTVError.badResponse }
        return o["epg_listings"] as? [[String: Any]] ?? []
    }

    private func entry(_ d: [String: Any]) -> EPGEntry? {
        guard let t = str(d["title"]), let tt = Data(base64Encoded: t).flatMap({ String(data: $0, encoding: .utf8) }),
              let s = int(d["start_timestamp"]), let e = int(d["stop_timestamp"]) else { return nil }
        return EPGEntry(title: tt, start: Date(timeIntervalSince1970: Double(s)), end: Date(timeIntervalSince1970: Double(e)))
    }

    /// The current and upcoming programs of a live channel.
    public func epgShort(streamId: String, limit: Int) async throws -> [EPGEntry] {
        try await listings("get_short_epg", streamId, ["limit": String(limit)]).compactMap(entry)
    }

    public func epgNow(streamId: String) async throws -> String? {
        try await epgShort(streamId: streamId, limit: 1).first?.title
    }

    public func epgArchive(streamId: String) async throws -> [EPGEntry] {
        try await listings("get_simple_data_table", streamId).compactMap(entry)
    }

    func seriesInfo(_ id: String) async throws -> [String: Any] {
        guard let o = try await json(urls.api("get_series_info", ["series_id": id])) as? [String: Any] else { throw IPTVError.badResponse }
        return o
    }
}
