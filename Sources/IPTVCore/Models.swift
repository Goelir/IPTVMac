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
