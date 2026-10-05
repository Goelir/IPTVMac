import Testing
import GRDB
@testable import IPTVCore

@Test func favoritesToggleAndList() throws {
    let (db, a) = try makeDB()
    try addItem(db, a, "One", sid: "1"); try addItem(db, a, "Two", sid: "2")
    let state = try db.dbQueue.write { try UserData.toggleFavorite($0, accountId: a, type: .live, streamId: "2") }
    #expect(state == true)
    #expect(try db.dbQueue.read { try UserData.favorites($0, accountId: a, type: .live).map(\.name) } == ["Two"])
    #expect(try db.dbQueue.read { try UserData.favoriteKeys($0, accountId: a) } == ["live:2"])
    let state2 = try db.dbQueue.write { try UserData.toggleFavorite($0, accountId: a, type: .live, streamId: "2") }
    #expect(state2 == false)
    #expect(try db.dbQueue.read { try UserData.favorites($0, accountId: a, type: .live) }.isEmpty)
}

@Test func progressResumesUnlessFinished() throws {
    let (db, a) = try makeDB()
    try db.dbQueue.write { d in
        try UserData.saveProgress(d, accountId: a, type: .movie, streamId: "9", position: 600, duration: 6000)
    }
    #expect(try db.dbQueue.read { try UserData.progress($0, accountId: a, type: .movie, streamId: "9") } == 600)
    try db.dbQueue.write { d in
        try UserData.saveProgress(d, accountId: a, type: .movie, streamId: "9", position: 5900, duration: 6000)
    }
    #expect(try db.dbQueue.read { try UserData.progress($0, accountId: a, type: .movie, streamId: "9") } == nil)
}

@Test func continueWatchingIsNewestFirstAndSkipsFinished() throws {
    let (db, a) = try makeDB()
    for (n, s) in [("Old", "1"), ("New", "2"), ("Done", "3")] { try addItem(db, a, n, type: .movie, sid: s) }
    try db.dbQueue.write { d in
        try UserData.saveProgress(d, accountId: a, type: .movie, streamId: "1", position: 10, duration: 100)
        try UserData.saveProgress(d, accountId: a, type: .movie, streamId: "3", position: 99, duration: 100)
        try UserData.saveProgress(d, accountId: a, type: .movie, streamId: "2", position: 10, duration: 100)
        try d.execute(sql: "UPDATE history SET updated = datetime('now','-1 day') WHERE streamId = '1'")
    }
    #expect(try db.dbQueue.read { try UserData.continueWatching($0, accountId: a, type: .movie).map(\.name) } == ["New", "Old"])
}

@Test func memorySecretStoreRoundTrip() throws {
    let s = MemorySecretStore()
    try s.setPassword("pw", for: 1); #expect(s.password(for: 1) == "pw")
    s.deletePassword(for: 1); #expect(s.password(for: 1) == nil)
}
