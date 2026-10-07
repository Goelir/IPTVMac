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
    #expect(try db.dbQueue.read { try UserData.favoriteKeys($0, accountId: a) } == ["\(a):live:2"])
    let state2 = try db.dbQueue.write { try UserData.toggleFavorite($0, accountId: a, type: .live, streamId: "2") }
    #expect(state2 == false)
    #expect(try db.dbQueue.read { try UserData.favorites($0, accountId: a, type: .live) }.isEmpty)
}

@Test func favoriteKeysAreAccountScopedSoPlaylistsReusingAStreamIdDoNotCollide() throws {
    let (db, a) = try makeDB()
    let b = try addAccount(db, "second")
    try addItem(db, a, "In A", sid: "7"); try addItem(db, b, "In B", sid: "7")
    _ = try db.dbQueue.write { try UserData.toggleFavorite($0, accountId: b, type: .live, streamId: "7") }
    let keys = try db.dbQueue.read { try UserData.favoriteKeys($0, accountId: nil) }
    #expect(keys == [UserData.favoriteKey(accountId: b, type: .live, streamId: "7")])
    #expect(!keys.contains(UserData.favoriteKey(accountId: a, type: .live, streamId: "7")))
    #expect(try db.dbQueue.read { try UserData.favoriteKeys($0, accountId: a) }.isEmpty)
}

@Test func favoritesAcrossAllPlaylists() throws {
    let (db, a) = try makeDB()
    let b = try addAccount(db, "second")
    try addItem(db, a, "In A", sid: "7"); try addItem(db, b, "In B", sid: "7"); try addItem(db, b, "Not fav", sid: "8")
    try db.dbQueue.write { d in
        _ = try UserData.toggleFavorite(d, accountId: a, type: .live, streamId: "7")
        _ = try UserData.toggleFavorite(d, accountId: b, type: .live, streamId: "7")
    }
    #expect(try db.dbQueue.read { try UserData.favorites($0, accountId: nil, type: .live).map(\.name) } == ["In A", "In B"])
    #expect(try db.dbQueue.read { try UserData.favorites($0, accountId: b, type: .live).map(\.name) } == ["In B"])
}

@Test func continueWatchingAcrossAllPlaylistsKeepsProgressPerPlaylist() throws {
    let (db, a) = try makeDB()
    let b = try addAccount(db, "second")
    try addItem(db, a, "Film A", type: .movie, sid: "1"); try addItem(db, b, "Film B", type: .movie, sid: "1")
    try db.dbQueue.write { d in
        try UserData.saveProgress(d, accountId: a, type: .movie, streamId: "1", position: 10, duration: 100)
        try UserData.saveProgress(d, accountId: b, type: .movie, streamId: "1", position: 50, duration: 100)
        try d.execute(sql: "UPDATE history SET updated = datetime('now','-1 day') WHERE accountId = ?", arguments: [a])
    }
    #expect(try db.dbQueue.read { try UserData.continueWatching($0, accountId: nil, type: .movie).map(\.name) } == ["Film B", "Film A"])
    #expect(try db.dbQueue.read { try UserData.continueWatching($0, accountId: a, type: .movie).map(\.name) } == ["Film A"])
    #expect(try db.dbQueue.read { try UserData.progress($0, accountId: b, type: .movie, streamId: "1") } == 50)
}

@Test func continueWatchingSeriesViaEpisodesDoesNotLeakIntoAPlaylistWithTheSameSeriesId() throws {
    let (db, a) = try makeDB()
    let b = try addAccount(db, "second")
    try addItem(db, a, "Show A", type: .series, sid: "5"); try addItem(db, b, "Show B", type: .series, sid: "5")
    try db.dbQueue.write { d in
        for aid in [a, b] { var e = Episode(accountId: aid, seriesId: "5", season: 1, number: 1, title: "E1", streamId: "100"); try e.insert(d) }
        try UserData.saveProgress(d, accountId: a, type: .series, streamId: "ep:100", position: 10, duration: 100)
    }
    #expect(try db.dbQueue.read { try UserData.continueWatching($0, accountId: nil, type: .series).map(\.name) } == ["Show A"])
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

@Test func savedPlaylistChoiceIsRestoredAndFallsBackSafely() {
    let a = Account(id: 1, name: "A", kind: .m3u), b = Account(id: 2, name: "B", kind: .m3u)
    #expect(Account.restore("all", from: [a, b]) == (all: true, account: a))
    #expect(Account.restore("2", from: [a, b]) == (all: false, account: b))
    #expect(Account.restore("9", from: [a, b]) == (all: false, account: a))      // that playlist was deleted
    #expect(Account.restore(nil, from: [a, b]) == (all: false, account: a))
    #expect(Account.restore("all", from: [a]) == (all: false, account: a))       // All needs more than one playlist
    #expect(Account.restore("all", from: []) == (all: false, account: nil))
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
    #expect(DatabaseSecretStore(db: db).password(for: a) == nil)                // removed with the account (a fresh store has no cache)
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
