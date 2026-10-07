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

    /// Playlists may reuse the same stream id, so a favorite is identified by its playlist too.
    public static func favoriteKey(accountId: Int64, type: ItemType, streamId: String) -> String { "\(accountId):\(type.rawValue):\(streamId)" }

    /// `accountId: nil` = every playlist (here and in the queries below).
    public static func favoriteKeys(_ db: Database, accountId: Int64?) throws -> Set<String> {
        Set(try Row.fetchAll(db, sql: "SELECT accountId, type, streamId FROM favorite WHERE (? IS NULL OR accountId=?)", arguments: [accountId, accountId])
            .map { favoriteKey(accountId: $0["accountId"], type: ItemType(rawValue: $0["type"]) ?? .live, streamId: $0["streamId"]) })
    }

    public static func favorites(_ db: Database, accountId: Int64?, type: ItemType) throws -> [Item] {
        try Item.fetchAll(db, sql: """
            SELECT item.* FROM item JOIN favorite f ON f.accountId=item.accountId AND f.type=item.type AND f.streamId=item.streamId
            WHERE (? IS NULL OR item.accountId=?) AND item.type=? ORDER BY item.id
            """, arguments: [accountId, accountId, type.rawValue])
    }

    public static func saveProgress(_ db: Database, accountId: Int64, type: ItemType, streamId: String,
                                    position: Double, duration: Double) throws {
        // 0 / 0 means "nothing played yet" (still loading, load failed): saving it would erase the real resume point.
        guard duration > 0, position.isFinite, duration.isFinite, position >= 0 else { return }
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

    public static func continueWatching(_ db: Database, accountId: Int64?, type: ItemType) throws -> [Item] {
        var items = try Item.fetchAll(db, sql: """
            SELECT item.* FROM item JOIN history h ON h.accountId=item.accountId AND h.type=item.type AND h.streamId=item.streamId
            WHERE (? IS NULL OR item.accountId=?) AND item.type=? AND (h.duration <= 0 OR h.position / h.duration <= 0.95)
            ORDER BY h.updated DESC
            """, arguments: [accountId, accountId, type.rawValue])
        if type == .series {
            // Xtream episodes are saved as "ep:<episodeId>": map them to their series through the cached episode list.
            let viaEpisodes = try Item.fetchAll(db, sql: """
                SELECT item.* FROM item JOIN (
                    SELECT e.accountId AS aid, e.seriesId AS sid, MAX(h.updated) AS u FROM history h
                    JOIN episode e ON e.accountId = h.accountId AND h.streamId = 'ep:' || e.streamId
                    WHERE (? IS NULL OR h.accountId = ?) AND h.type = 'series' AND (h.duration <= 0 OR h.position / h.duration <= 0.95)
                    GROUP BY e.accountId, e.seriesId) x ON x.aid = item.accountId AND x.sid = item.streamId
                WHERE item.type = 'series' ORDER BY x.u DESC
                """, arguments: [accountId, accountId])
            let have = Set(items.compactMap(\.id))
            items = viaEpisodes.filter { !have.contains($0.id ?? -1) } + items
        }
        return items
    }
}
