import Foundation
import GRDB

/// "Hide categories": a plain name filter (not a parental lock). Built from the comma-separated preference (Arabic comma too).
public struct CategoryFilter: Sendable {
    public let words: [String]

    public init(_ csv: String) {
        words = csv.split(whereSeparator: { $0 == "," || $0 == "،" }).map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty }
    }

    public var isEmpty: Bool { words.isEmpty }

    public func hides(_ name: String) -> Bool { words.contains { name.range(of: $0, options: .caseInsensitive) != nil } }

    public func visible(_ categories: [Category]) -> [Category] { categories.filter { !hides($0.name) } }

    /// Drops the items of hidden categories (a category is a playlist + type + remote id). Items without a category stay.
    public func visible(_ items: [Item], in db: Database) throws -> [Item] {
        guard !isEmpty else { return items }
        let hidden = Set(try Category.fetchAll(db).filter { hides($0.name) }.map { Self.key($0.accountId, $0.type, $0.remoteId) })
        guard !hidden.isEmpty else { return items }
        return items.filter { i in i.categoryId.map { !hidden.contains(Self.key(i.accountId, i.type, $0)) } ?? true }
    }

    private static func key(_ account: Int64, _ type: ItemType, _ remoteId: String) -> String { "\(account)|\(type.rawValue)|\(remoteId)" }
}
