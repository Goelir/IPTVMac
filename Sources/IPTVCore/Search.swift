import Foundation
import GRDB

public struct SearchRequest {
    public var accountId: Int64?          // nil = every playlist
    public var text: String
    public var type: ItemType?
    public var categoryId: String?
    public var limit: Int
    public init(accountId: Int64?, text: String = "", type: ItemType? = nil, categoryId: String? = nil, limit: Int = 5000) {
        self.accountId = accountId; self.text = text; self.type = type; self.categoryId = categoryId; self.limit = limit
    }
}

public enum Search {
    public static func run(_ db: Database, _ r: SearchRequest) throws -> [Item] {
        if r.accountId == nil, r.text.allSatisfy(\.isWhitespace) {   // browsing every playlist: each gets an equal share, or the first one fills the limit
            let ids = try Int64.fetchAll(db, sql: "SELECT DISTINCT accountId FROM item" + (r.type == nil ? "" : " WHERE type = ?") + " ORDER BY accountId",
                                         arguments: StatementArguments(r.type.map { [$0.rawValue] } ?? []))
            if ids.count > 1 {
                return try ids.flatMap { id -> [Item] in var q = r; q.accountId = id; q.limit = max(1, r.limit / ids.count); return try run(db, q) }
            }
        }
        // Every word is a prefix term; 180 of them take seconds on 100k rows and a cancelled Task cannot interrupt the SQL.
        let trimmed = r.text.split(whereSeparator: \.isWhitespace).prefix(8).joined(separator: " ")
        var sql = "SELECT item.* FROM item"
        var args: [DatabaseValueConvertible] = []
        if !trimmed.isEmpty {
            guard let pattern = FTS5Pattern(matchingAllPrefixesIn: trimmed) else { return [] }
            sql += " JOIN item_fts ON item_fts.rowid = item.id AND item_fts MATCH ?"
            args.append(pattern.rawPattern)
        }
        var conds: [String] = []
        if let a = r.accountId { conds.append("item.accountId = ?"); args.append(a) }
        if let t = r.type { conds.append("item.type = ?"); args.append(t.rawValue) }
        if let c = r.categoryId { conds.append("item.categoryId = ?"); args.append(c) }
        if !conds.isEmpty { sql += " WHERE " + conds.joined(separator: " AND ") }
        sql += trimmed.isEmpty ? " ORDER BY item.id" : " ORDER BY rank"
        sql += " LIMIT ?"; args.append(r.limit)
        return try Item.fetchAll(db, sql: sql, arguments: StatementArguments(args))
    }
}
