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

@Test func nilAccountSearchesEveryPlaylistAndSingleAccountStaysIsolated() throws {
    let (db, a) = try makeDB()
    let b = try addAccount(db, "second")
    try addItem(db, a, "Alpha One", sid: "1"); try addItem(db, b, "Alpha Two", sid: "1")   // same streamId in both playlists
    #expect(try run(db, .init(accountId: nil, text: "alpha")).sorted() == ["Alpha One", "Alpha Two"])
    #expect(try run(db, .init(accountId: a, text: "alpha")) == ["Alpha One"])
    #expect(try run(db, .init(accountId: b, text: "alpha")) == ["Alpha Two"])
    #expect(try run(db, .init(accountId: nil, text: "", type: .live, categoryId: "1")).count == 2)
}

@Test func browsingEveryPlaylistGivesEachOneAShareOfTheLimit() throws {
    let (db, a) = try makeDB()
    let b = try addAccount(db, "second")
    for i in 0..<20 { try addItem(db, a, "A\(i)") }
    for i in 0..<20 { try addItem(db, b, "B\(i)") }
    let names = try run(db, .init(accountId: nil, type: .live, limit: 10))
    #expect(names.count == 10)
    #expect(names.filter { $0.hasPrefix("A") }.count == 5 && names.filter { $0.hasPrefix("B") }.count == 5)
}

@Test func aPlaylistWithoutThatTypeDoesNotTakeAShareOfTheLimit() throws {
    let (db, a) = try makeDB()
    let b = try addAccount(db, "live only")
    for i in 0..<20 { try addItem(db, a, "Film \(i)", type: .movie) }
    try addItem(db, b, "Channel", type: .live)
    #expect(try run(db, .init(accountId: nil, type: .movie, limit: 10)).count == 10)
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

@Test func allPlaylistsSearchStaysFastOn100kItems() throws {
    let (db, a) = try makeDB()
    let b = try addAccount(db, "second")
    try db.dbQueue.write { d in
        let st = try d.makeStatement(sql: "INSERT INTO item (accountId,type,name,categoryId,streamId) VALUES (?,?,?,?,?)")
        for i in 0..<100_000 { try st.execute(arguments: [i % 2 == 0 ? a : b, "live", "Channel \(i) \(i % 7 == 0 ? "Sport" : "News")", "\(i % 50)", "\(i)"]) }
    }
    for r in [SearchRequest(accountId: nil, text: "spor 99"), SearchRequest(accountId: nil, text: "", type: .live)] {
        let t0 = Date()
        let hits = try db.dbQueue.read { try Search.run($0, r) }
        let ms = Date().timeIntervalSince(t0) * 1000
        #expect(!hits.isEmpty)
        #expect(ms < 250, "search \"\(r.text)\" took \(ms) ms")
    }
}
