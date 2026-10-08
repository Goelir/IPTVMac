import Foundation
import GRDB

public enum ItemType: String, Codable, CaseIterable, Sendable, DatabaseValueConvertible { case live, movie, series }
public enum AccountKind: String, Codable, Sendable, DatabaseValueConvertible { case xtream, m3u }

public struct Account: Codable, Identifiable, Hashable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "account"
    public var id: Int64?
    public var name: String
    public var kind: AccountKind
    public var server: String?
    public var username: String?
    public var url: String?
    public init(id: Int64? = nil, name: String, kind: AccountKind, server: String? = nil,
                username: String? = nil, url: String? = nil) {
        self.id = id; self.name = name; self.kind = kind
        self.server = server; self.username = username; self.url = url
    }
    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }

    /// The playlist choice to open with, from the saved value ("all" or an account id). A deleted playlist falls back to the first,
    /// and All needs more than one playlist.
    public static func restore(_ saved: String?, from accounts: [Account]) -> (all: Bool, account: Account?) {
        (saved == "all" && accounts.count > 1, accounts.first { String($0.id ?? 0) == saved } ?? accounts.first)
    }
}

public struct Category: Codable, Identifiable, Hashable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "category"
    public var id: Int64?
    public var accountId: Int64
    public var type: ItemType
    public var remoteId: String
    public var name: String
    public init(id: Int64? = nil, accountId: Int64, type: ItemType, remoteId: String, name: String) {
        self.id = id; self.accountId = accountId; self.type = type; self.remoteId = remoteId; self.name = name
    }
    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}

public struct Item: Codable, Identifiable, Hashable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "item"
    public var id: Int64?
    public var accountId: Int64
    public var type: ItemType
    public var name: String
    public var categoryId: String?
    public var icon: String?
    public var rating: String?
    public var streamId: String
    public var containerExt: String?
    public var directURL: String?
    public var tvArchive: Bool
    public var archiveDays: Int
    public var epgChannelId: String?
    public init(id: Int64? = nil, accountId: Int64, type: ItemType, name: String, streamId: String,
                categoryId: String? = nil, icon: String? = nil, rating: String? = nil,
                containerExt: String? = nil, directURL: String? = nil, tvArchive: Bool = false,
                archiveDays: Int = 0, epgChannelId: String? = nil) {
        self.id = id; self.accountId = accountId; self.type = type; self.name = name
        self.streamId = streamId; self.categoryId = categoryId; self.icon = icon; self.rating = rating
        self.containerExt = containerExt; self.directURL = directURL; self.tvArchive = tvArchive
        self.archiveDays = archiveDays; self.epgChannelId = epgChannelId
    }
    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }

    /// The logo/poster URL is provider-controlled and fetched without a click: see `RemoteImage.safeURL`.
    public var iconURL: URL? { RemoteImage.safeURL(icon) }
}

/// Image links come from the provider and are fetched without a click: http(s) only, and never a device on the user's own
/// network (a `tvg-logo="http://192.168.1.1/reboot"` would be a browse-to-trigger request).
public enum RemoteImage {
    public static func safeURL(_ s: String?) -> URL? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), s.utf8.count <= 2048, let u = URL(string: s),
              ["http", "https"].contains(u.scheme?.lowercased() ?? ""), let h = u.host?.lowercased(), !h.isEmpty else { return nil }
        if h == "localhost" || h.hasSuffix(".local") || h.hasSuffix(".internal") || h.hasSuffix(".lan") || !h.contains(".") && !h.contains(":") { return nil }
        let p = h.split(separator: ".").compactMap { Int($0) }
        if p.count == 4 {
            if p[0] == 10 || p[0] == 127 || p[0] == 0 || (p[0] == 169 && p[1] == 254) || (p[0] == 192 && p[1] == 168) || (p[0] == 172 && (16...31).contains(p[1])) { return nil }
        }
        if h.contains(":") && (h == "::1" || h.hasPrefix("fe80") || h.hasPrefix("fc") || h.hasPrefix("fd")) { return nil }
        return u
    }
}

public struct Episode: Codable, Identifiable, Hashable, FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "episode"
    public var id: Int64?
    public var accountId: Int64
    public var seriesId: String
    public var season: Int
    public var number: Int
    public var title: String
    public var streamId: String
    public var containerExt: String?
    public init(id: Int64? = nil, accountId: Int64, seriesId: String, season: Int, number: Int,
                title: String, streamId: String, containerExt: String? = nil) {
        self.id = id; self.accountId = accountId; self.seriesId = seriesId; self.season = season
        self.number = number; self.title = title; self.streamId = streamId; self.containerExt = containerExt
    }
    public mutating func didInsert(_ inserted: InsertionSuccess) { id = inserted.rowID }
}
