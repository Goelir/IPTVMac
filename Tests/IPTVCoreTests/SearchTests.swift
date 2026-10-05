import Foundation
import Testing
import GRDB
@testable import IPTVCore

private func run(_ db: AppDatabase, _ r: SearchRequest) throws -> [String] {
    try db.dbQueue.read { try Search.run($0, r).map(\.name) }
}

@Test func prefixSearchMatchesEveryToken() throws {
    let (db, a) = try makeDB()
    try addItem(db, a, "Game of Thrones", type: .series)
    try addItem(db, a, "Gamer Girl", type: .movie)
    #expect(try run(db, .init(accountId: a, text: "gam")).count == 2)
    #expect(try run(db, .init(accountId: a, text: "game thr")) == ["Game of Thrones"])
}

@Test func scopesNarrowResults() throws {
    let (db, a) = try makeDB()
    try addItem(db, a, "Alpha One", type: .live, cat: "1")
    try addItem(db, a, "Alpha Two", type: .live, cat: "2")
    try addItem(db, a, "Alpha Film", type: .movie, cat: "9")
    #expect(try run(db, .init(accountId: a, text: "alpha")).count == 3)
    #expect(try run(db, .init(accountId: a, text: "alpha", type: .live)).count == 2)
    #expect(try run(db, .init(accountId: a, text: "alpha", type: .live, categoryId: "2")) == ["Alpha Two"])
}

@Test func emptyTextBrowsesInInsertionOrder() throws {
    let (db, a) = try makeDB()
    for n in ["Zeta", "Alpha", "Mid"] { try addItem(db, a, n, cat: "1") }
    #expect(try run(db, .init(accountId: a, text: "  ", type: .live, categoryId: "1")) == ["Zeta", "Alpha", "Mid"])
}

@Test func fts5SyntaxCharactersNeverThrow() throws {
    let (db, a) = try makeDB()
    try addItem(db, a, "Rock and Roll")
    for q in [#"""#, "rock*", "-rock", "rock AND", "(rock", "NEAR(", "rock OR", "'", "a\"b"] {
        _ = try run(db, .init(accountId: a, text: q))
    }
    #expect(try run(db, .init(accountId: a, text: #""*-"#)).isEmpty)
}

@Test func accentsAndHebrewPrefixMatch() throws {
    let (db, a) = try makeDB()
    try addItem(db, a, "Café Society", type: .movie)
    try addItem(db, a, "שלום עולם", type: .movie)
    #expect(try run(db, .init(accountId: a, text: "cafe")) == ["Café Society"])
    #expect(try run(db, .init(accountId: a, text: "שלו")) == ["שלום עולם"])
}

@Test func otherAccountsAreInvisible() throws {
    let (db, a) = try makeDB()
    try addItem(db, a, "Mine")
    #expect(try run(db, .init(accountId: a + 1, text: "mine")).isEmpty)
}

@Test func searchStaysFastOn100kItems() throws {
    let (db, a) = try makeDB()
    try db.dbQueue.write { d in
        let st = try d.makeStatement(sql: "INSERT INTO item (accountId,type,name,categoryId,streamId) VALUES (?,?,?,?,?)")
        for i in 0..<100_000 { try st.execute(arguments: [a, "live", "Channel \(i) \(i % 7 == 0 ? "Sport" : "News")", "\(i % 50)", "\(i)"]) }
    }
    let t0 = Date()
    let hits = try db.dbQueue.read { try Search.run($0, .init(accountId: a, text: "spor 99")) }
    let ms = Date().timeIntervalSince(t0) * 1000
    #expect(!hits.isEmpty)
    #expect(ms < 250, "search took \(ms) ms")
}
