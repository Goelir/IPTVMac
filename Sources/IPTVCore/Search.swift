import Foundation
import GRDB

public struct SearchRequest {
    public var accountId: Int64
    public var text: String
    public var type: ItemType?
    public var categoryId: String?
    public var limit: Int
    public init(accountId: Int64, text: String = "", type: ItemType? = nil, categoryId: String? = nil, limit: Int = 5000) {
        self.accountId = accountId; self.text = text; self.type = type; self.categoryId = categoryId; self.limit = limit
    }
}

public enum Search {
    public static func run(_ db: Database, _ r: SearchRequest) throws -> [Item] {
        let trimmed = r.text.trimmingCharacters(in: .whitespacesAndNewlines)
        var sql = "SELECT item.* FROM item"
        var args: [DatabaseValueConvertible] = []
        if !trimmed.isEmpty {
            guard let pattern = FTS5Pattern(matchingAllPrefixesIn: trimmed) else { return [] }
            sql += " JOIN item_fts ON item_fts.rowid = item.id AND item_fts MATCH ?"
            args.append(pattern.rawPattern)
        }
        sql += " WHERE item.accountId = ?"; args.append(r.accountId)
        if let t = r.type { sql += " AND item.type = ?"; args.append(t.rawValue) }
        if let c = r.categoryId { sql += " AND item.categoryId = ?"; args.append(c) }
        sql += trimmed.isEmpty ? " ORDER BY item.id" : " ORDER BY rank"
        sql += " LIMIT ?"; args.append(r.limit)
        return try Item.fetchAll(db, sql: sql, arguments: StatementArguments(args))
    }
}
