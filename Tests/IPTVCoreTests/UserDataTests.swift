import Foundation
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

@Test func databaseSecretStoreRoundTripAndCascade() throws {
    let (db, a) = try makeDB()
    let s = DatabaseSecretStore(db: db)
    #expect(s.password(for: a) == nil)
    try s.setPassword("pw1", for: a); #expect(s.password(for: a) == "pw1")
    try s.setPassword("pw2", for: a); #expect(s.password(for: a) == "pw2")      // overwrite
    try db.dbQueue.write { try $0.execute(sql: "DELETE FROM account WHERE id = ?", arguments: [a]) }
    #expect(s.password(for: a) == nil)                                          // removed with the account
    let (db2, b) = try makeDB()
    let s2 = DatabaseSecretStore(db: db2)
    try s2.setPassword("x", for: b); s2.deletePassword(for: b); #expect(s2.password(for: b) == nil)
}

@Test func passwordsSurviveReopeningTheDatabaseFile() throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent("iptvmac-\(UUID().uuidString).sqlite").path
    defer { try? FileManager.default.removeItem(atPath: path) }
    var id: Int64 = 0
    do {
        let db = try AppDatabase(path: path)
        id = try db.dbQueue.write { d in var a = Account(name: "n", kind: .xtream, server: "h", username: "u"); try a.insert(d); return a.id! }
        try DatabaseSecretStore(db: db).setPassword("kept", for: id)
    }
    let reopened = try AppDatabase(path: path)
    #expect(DatabaseSecretStore(db: reopened).password(for: id) == "kept")
    let attrs = try FileManager.default.attributesOfItem(atPath: path)
    #expect((attrs[.posixPermissions] as? Int ?? 0) & 0o077 == 0, "database file must be readable by the owner only")
}
