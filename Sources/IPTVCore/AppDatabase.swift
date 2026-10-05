import Foundation
import GRDB

public final class AppDatabase {
    public let dbQueue: DatabaseQueue

    public init(path: String? = nil) throws {
        dbQueue = try path.map { try DatabaseQueue(path: $0) } ?? DatabaseQueue()
        try Self.migrator.migrate(dbQueue)
        if let path { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path) }
    }

    public static func defaultPath() throws -> String {
        let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                              appropriateFor: nil, create: true).appendingPathComponent("IPTVMac")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        return dir.appendingPathComponent("iptv.sqlite").path
    }

    static var migrator: DatabaseMigrator {
        var m = DatabaseMigrator()
        m.registerMigration("v1") { db in
            try db.create(table: "account") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("kind", .text).notNull()
                t.column("server", .text); t.column("username", .text); t.column("url", .text)
            }
            try db.create(table: "category") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("accountId", .integer).notNull().references("account", onDelete: .cascade)
                t.column("type", .text).notNull()
                t.column("remoteId", .text).notNull()
                t.column("name", .text).notNull()
                t.uniqueKey(["accountId", "type", "remoteId"])
            }
            try db.create(table: "item") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("accountId", .integer).notNull().references("account", onDelete: .cascade)
                t.column("type", .text).notNull()
                t.column("name", .text).notNull()
                t.column("categoryId", .text)
                t.column("icon", .text); t.column("rating", .text)
                t.column("streamId", .text).notNull()
                t.column("containerExt", .text); t.column("directURL", .text)
                t.column("tvArchive", .boolean).notNull().defaults(to: false)
                t.column("archiveDays", .integer).notNull().defaults(to: 0)
                t.column("epgChannelId", .text)
                t.column("stale", .boolean).notNull().defaults(to: false)
                t.uniqueKey(["accountId", "type", "streamId"])
            }
            try db.create(index: "item_category", on: "item", columns: ["accountId", "type", "categoryId"])
            try db.create(virtualTable: "item_fts", using: FTS5()) { t in
                t.synchronize(withTable: "item")
                t.tokenizer = .unicode61(diacritics: .remove)
                t.column("name")
            }
            try db.create(table: "episode") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("accountId", .integer).notNull().references("account", onDelete: .cascade)
                t.column("seriesId", .text).notNull()
                t.column("season", .integer).notNull()
                t.column("number", .integer).notNull()
                t.column("title", .text).notNull()
                t.column("streamId", .text).notNull()
                t.column("containerExt", .text)
                t.uniqueKey(["accountId", "streamId"])
            }
            try db.create(table: "favorite") { t in
                t.column("accountId", .integer).notNull()
                t.column("type", .text).notNull()
                t.column("streamId", .text).notNull()
                t.primaryKey(["accountId", "type", "streamId"])
            }
            try db.create(table: "history") { t in
                t.column("accountId", .integer).notNull()
                t.column("type", .text).notNull()
                t.column("streamId", .text).notNull()
                t.column("position", .double).notNull()
                t.column("duration", .double).notNull()
                t.column("updated", .datetime).notNull()
                t.primaryKey(["accountId", "type", "streamId"])
            }
        }
        // Account passwords live in the same private database file (no Keychain: it prompts for access on every new build).
        m.registerMigration("v2-secret") { db in
            try db.create(table: "secret") { t in
                t.column("accountId", .integer).primaryKey().references("account", onDelete: .cascade)
                t.column("password", .text).notNull()
            }
        }
        return m
    }
}
