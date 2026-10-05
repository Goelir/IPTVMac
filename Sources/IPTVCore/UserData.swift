import Foundation
import GRDB

public enum UserData {
    public static func toggleFavorite(_ db: Database, accountId: Int64, type: ItemType, streamId: String) throws -> Bool {
        let args: StatementArguments = [accountId, type.rawValue, streamId]
        let exists = try Bool.fetchOne(db, sql: "SELECT EXISTS(SELECT 1 FROM favorite WHERE accountId=? AND type=? AND streamId=?)", arguments: args) ?? false
        try db.execute(sql: exists ? "DELETE FROM favorite WHERE accountId=? AND type=? AND streamId=?"
                                   : "INSERT INTO favorite (accountId,type,streamId) VALUES (?,?,?)", arguments: args)
        return !exists
    }

    public static func favoriteKeys(_ db: Database, accountId: Int64) throws -> Set<String> {
        Set(try Row.fetchAll(db, sql: "SELECT type, streamId FROM favorite WHERE accountId=?", arguments: [accountId])
            .map { "\($0["type"] as String):\($0["streamId"] as String)" })
    }

    public static func favorites(_ db: Database, accountId: Int64, type: ItemType) throws -> [Item] {
        try Item.fetchAll(db, sql: """
            SELECT item.* FROM item JOIN favorite f ON f.accountId=item.accountId AND f.type=item.type AND f.streamId=item.streamId
            WHERE item.accountId=? AND item.type=? ORDER BY item.id
            """, arguments: [accountId, type.rawValue])
    }

    public static func saveProgress(_ db: Database, accountId: Int64, type: ItemType, streamId: String,
                                    position: Double, duration: Double) throws {
        try db.execute(sql: """
            INSERT INTO history (accountId,type,streamId,position,duration,updated) VALUES (?,?,?,?,?,datetime('now'))
            ON CONFLICT(accountId,type,streamId) DO UPDATE SET position=excluded.position, duration=excluded.duration, updated=excluded.updated
            """, arguments: [accountId, type.rawValue, streamId, position, duration])
    }

    public static func progress(_ db: Database, accountId: Int64, type: ItemType, streamId: String) throws -> Double? {
        guard let r = try Row.fetchOne(db, sql: "SELECT position, duration FROM history WHERE accountId=? AND type=? AND streamId=?",
                                       arguments: [accountId, type.rawValue, streamId]) else { return nil }
        let p: Double = r["position"], d: Double = r["duration"]
        return (d > 0 && p / d > 0.95) || p < 5 ? nil : p
    }

    public static func continueWatching(_ db: Database, accountId: Int64, type: ItemType) throws -> [Item] {
        try Item.fetchAll(db, sql: """
            SELECT item.* FROM item JOIN history h ON h.accountId=item.accountId AND h.type=item.type AND h.streamId=item.streamId
            WHERE item.accountId=? AND item.type=? AND (h.duration <= 0 OR h.position / h.duration <= 0.95)
            ORDER BY h.updated DESC
            """, arguments: [accountId, type.rawValue])
    }
}
