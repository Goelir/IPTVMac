import Testing
import Foundation
import GRDB
@testable import IPTVCore

// The info cache: 14-day TTL, one row per (playlist, type, stream id), gone with its playlist, added by a new migration.

private func sample(_ plot: String = "A plot.") -> ItemInfo { response(#"{"plot":"\#(plot)","rating":"7.5","youtube_trailer":"dQw4w9WgXcQ"}"#) }
private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
private let day: TimeInterval = 86_400

private func get(_ db: AppDatabase, _ a: Int64, _ type: ItemType = .movie, _ sid: String = "10", at now: Date = t0, maxAge: TimeInterval? = ItemInfoStore.ttl) throws -> ItemInfo? {
    try db.dbQueue.read { try ItemInfoStore.cached($0, accountId: a, type: type, streamId: sid, now: now, maxAge: maxAge) }
}
private func put(_ db: AppDatabase, _ a: Int64, _ info: ItemInfo, _ type: ItemType = .movie, _ sid: String = "10", at now: Date = t0) throws {
    try db.dbQueue.write { try ItemInfoStore.save($0, accountId: a, type: type, streamId: sid, info: info, now: now) }
}

@Test func infoIsServedFromTheCacheForFourteenDays() throws {
    let (db, a) = try makeDB()
    #expect(try get(db, a) == nil)
    try put(db, a, sample())
    #expect(try get(db, a) == sample())
    #expect(try get(db, a, at: t0.addingTimeInterval(14 * day - 60)) == sample())       // just inside the TTL
    #expect(try get(db, a, at: t0.addingTimeInterval(14 * day + 60)) == nil)            // expired
    #expect(try get(db, a, at: t0.addingTimeInterval(400 * day), maxAge: nil) == sample())   // a stale copy is still usable when the network fails
    #expect(ItemInfoStore.ttl == 14 * day)
}

@Test func theCacheIsKeyedByPlaylistTypeAndStreamId() throws {
    let (db, a) = try makeDB()
    let b = try addAccount(db, "other")
    try put(db, a, sample("one"))
    #expect(try get(db, b) == nil)                                                       // same id in another playlist
    #expect(try get(db, a, .series) == nil)                                              // same id, other type
    #expect(try get(db, a, .movie, "11") == nil)
    try put(db, a, sample("two"))                                                        // saving again replaces
    #expect(try get(db, a)?.plot == "two")
    #expect(try db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT count(*) FROM item_info") } == 1)
}

@Test func savingDropsRowsThatAreAlreadyExpired() throws {
    let (db, a) = try makeDB()
    try put(db, a, sample("old"), .movie, "1", at: t0)
    try put(db, a, sample("new"), .movie, "2", at: t0.addingTimeInterval(20 * day))
    #expect(try db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT count(*) FROM item_info") } == 1)
    #expect(try get(db, a, .movie, "2", at: t0.addingTimeInterval(20 * day))?.plot == "new")
}

@Test func aCorruptRowIsTreatedAsMissing() throws {
    let (db, a) = try makeDB()
    try db.dbQueue.write { d in
        try d.execute(sql: "INSERT INTO item_info (accountId,type,streamId,json,fetched) VALUES (?,?,?,?,?)", arguments: [a, "movie", "10", "not json", t0])
    }
    #expect(try get(db, a) == nil)
}

@Test func deletingAPlaylistDeletesItsCachedInfo() throws {
    let (db, a) = try makeDB()
    let b = try addAccount(db, "keep")
    try put(db, a, sample()); try put(db, b, sample())
    _ = try db.dbQueue.write { try Account.deleteOne($0, key: a) }
    #expect(try get(db, a) == nil)
    #expect(try get(db, b) == sample())
}

@Test func theCacheHoldsOnlyTheParsedFieldsNeverCredentials() throws {
    let (db, a) = try makeDB()
    let raw = #"{"info":{"plot":"p","username":"u1","password":"pw1","url":"http://h/movie/u1/pw1/10.mp4"},"user_info":{"username":"u1","password":"pw1"},"movie_data":{"container_extension":"mkv"}}"#
    let obj = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as! [String: Any]
    try put(db, a, ItemInfo(response: obj))
    let stored = try #require(try db.dbQueue.read { try String.fetchOne($0, sql: "SELECT json FROM item_info") })
    #expect(stored.contains("\"plot\""))
    for secret in ["pw1", "u1", "password", "username", "movie/"] { #expect(!stored.contains(secret), "\(secret)") }
}

@Test func aDatabaseFromBeforeTheInfoCacheUpgradesAndKeepsItsData() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("iptvmac-mig-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let path = dir.appendingPathComponent("old.sqlite").path
    do {   // an existing install: migrations up to v3 only
        let old = try DatabaseQueue(path: path)
        try AppDatabase.migrator.migrate(old, upTo: "v3-fts-trigger")
        try old.write { d in
            try d.execute(sql: "INSERT INTO account (id,name,kind,server,username) VALUES (1,'p','xtream','http://h','u')")
            try d.execute(sql: "INSERT INTO item (accountId,type,name,streamId) VALUES (1,'movie','Keep me','10')")
            #expect(!(try d.tableExists("item_info")))
        }
    }
    let db = try AppDatabase(path: path)
    #expect(try db.dbQueue.read { try $0.tableExists("item_info") })
    #expect(try db.dbQueue.read { try Item.fetchCount($0) } == 1)
    try put(db, 1, sample())
    #expect(try get(db, 1) == sample())
    #expect(FileManager.default.fileExists(atPath: path + ".bak"))                      // the existing backup-before-migration still happens
}

@Test func imageLinksInACachedRowAreCheckedAgainWhenItIsRead() throws {
    let (db, a) = try makeDB()
    let json = #"{"plot":"p","posterURL":"http://192.168.1.1/reboot","backdropURL":"https://cdn.example.com/b.jpg","trailerID":"x/../evil"}"#   // as an older version or a tampered file could have left it
    try db.dbQueue.write { d in
        try d.execute(sql: "INSERT INTO item_info (accountId,type,streamId,json,fetched) VALUES (?,?,?,?,?)", arguments: [a, "movie", "10", json, t0])
    }
    let i = try #require(try get(db, a))
    #expect(i.plot == "p"); #expect(i.posterURL == nil); #expect(i.backdropURL?.host == "cdn.example.com")
    #expect(i.trailerID == nil); #expect(i.trailerURL == nil)
}
