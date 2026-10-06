import Foundation
import Testing
import GRDB
@testable import IPTVCore

@Test func fts5IsKeptInSyncWithItems() throws {
    let (db, aid) = try makeDB()
    try addItem(db, aid, "Hello World")
    let hits = try db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT count(*) FROM item_fts WHERE item_fts MATCH 'hello'") }
    #expect(hits == 1)
    try db.dbQueue.write { try $0.execute(sql: "DELETE FROM item") }
    let after = try db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT count(*) FROM item_fts WHERE item_fts MATCH 'hello'") }
    #expect(after == 0)
}

@Test func duplicateStreamIdIsRejected() throws {
    let (db, aid) = try makeDB()
    try addItem(db, aid, "A", sid: "1")
    #expect(throws: (any Error).self) { try addItem(db, aid, "B", sid: "1") }
}

// MARK: hardening (audit)

@Test func m3uNeverUsesTheUrlWithCredentialsAsTheTitle() {
    var p = M3UParser()
    #expect(p.feed("http://host:80/live/USER/PASS/1.ts")?.name == "1.ts")
    _ = p.feed("#EXTINF:-1 group-title=\"G\",")                     // empty title after the comma
    #expect(p.feed("http://host/live/USER/PASS/77.ts?token=abc")?.name == "77.ts")
    let huge = "#EXTINF:-1 " + String(repeating: "a", count: 200_000)
    #expect(p.feed(huge) == nil)                                      // an oversized attribute line is ignored, quickly
}

@Test func xtreamUrlsToleratePastedApiLinksAndWhitespace() throws {
    let u = try #require(XtreamURLs(server: " http://h:8080/get.php?username=u&password=p&type=m3u_plus \n", username: " user\n", password: "pw "))
    #expect(u.api("x").absoluteString == "http://h:8080/player_api.php?username=user&password=pw&action=x")
    let v = try #require(XtreamURLs(server: "h.example/player_api.php?username=a", username: "u", password: "p"))
    #expect(v.live(id: "5").absoluteString == "http://h.example/live/u/p/5.ts")
    let w = try #require(XtreamURLs(server: "https://h.example/panel/c/", username: "u", password: "p"))
    #expect(w.live(id: "5").absoluteString == "https://h.example/panel/live/u/p/5.ts")
}

@Test func progressWithoutADurationNeverOverwritesTheResumePoint() throws {
    let (db, a) = try makeDB()
    try db.dbQueue.write { d in
        try UserData.saveProgress(d, accountId: a, type: .movie, streamId: "9", position: 600, duration: 6000)
        try UserData.saveProgress(d, accountId: a, type: .movie, streamId: "9", position: 0, duration: 0)           // still loading
        try UserData.saveProgress(d, accountId: a, type: .movie, streamId: "9", position: .nan, duration: 6000)
    }
    #expect(try db.dbQueue.read { try UserData.progress($0, accountId: a, type: .movie, streamId: "9") } == 600)
}

@Test func syncKeepsATypeThatCameBackEmptyAndOtherTypesAreReplaced() async throws {
    let (db, a) = try makeDB()
    try await db.dbQueue.write { d in
        for (t, id) in [(ItemType.live, "1"), (.movie, "2")] { var i = Item(accountId: a, type: t, name: "n\(id)", streamId: id); try i.insert(d) }
    }
    // ponytail: exercised through the same SQL as SyncService: only the types present in the new list are marked stale
    let types = ["movie"]
    let typeList = types.map { "'\($0)'" }.joined(separator: ",")
    try await db.dbQueue.write { d in
        try d.execute(sql: "UPDATE item SET stale = 1 WHERE accountId = ? AND type IN (\(typeList))", arguments: [a])
        try d.execute(sql: "DELETE FROM item WHERE accountId = ? AND stale = 1", arguments: [a])
    }
    let left = try await db.dbQueue.read { try Item.filter(Column("accountId") == a).fetchAll($0).map(\.type) }
    #expect(left == [.live])
}

@Test func continueWatchingShowsASeriesWhoseEpisodeWasStarted() throws {
    let (db, a) = try makeDB()
    try db.dbQueue.write { d in
        var s = Item(accountId: a, type: .series, name: "Show", streamId: "S1"); try s.insert(d)
        var e = Episode(accountId: a, seriesId: "S1", season: 1, number: 1, title: "Pilot", streamId: "501"); try e.insert(d)
        try UserData.saveProgress(d, accountId: a, type: .series, streamId: "ep:501", position: 600, duration: 2700)
    }
    let items = try db.dbQueue.read { try UserData.continueWatching($0, accountId: a, type: .series) }
    #expect(items.map(\.name) == ["Show"])
}

@Test func fileDatabaseUsesWalAndKeepsPrivatePermissions() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("iptvmac-db-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let path = dir.appendingPathComponent("t.sqlite").path
    let db = try AppDatabase(path: path)
    #expect(try db.dbQueue.read { try String.fetchOne($0, sql: "PRAGMA journal_mode") } == "wal")
    try db.dbQueue.write { d in var a = Account(name: "x", kind: .m3u, url: "http://h/l.m3u"); try a.insert(d) }
    for suffix in ["", "-wal", "-shm"] where FileManager.default.fileExists(atPath: path + suffix) {
        let mode = (try FileManager.default.attributesOfItem(atPath: path + suffix)[.posixPermissions] as? Int) ?? 0
        #expect(mode & 0o077 == 0, "\(suffix) must not be readable by others")
    }
    // the FTS trigger now only fires on a name change but must still keep the index right
    try db.dbQueue.write { d in
        var i = Item(accountId: 1, type: .live, name: "Alpha", streamId: "1"); try i.insert(d)
        try d.execute(sql: "UPDATE item SET icon = 'x' WHERE streamId = '1'")
        try d.execute(sql: "UPDATE item SET name = 'Bravo' WHERE streamId = '1'")
    }
    #expect(try db.dbQueue.read { try Search.run($0, SearchRequest(accountId: 1, text: "bra")).count } == 1)
    #expect(try db.dbQueue.read { try Search.run($0, SearchRequest(accountId: 1, text: "alp")).count } == 0)
}

@Test func aCorruptDatabaseFileIsMovedAsideNotDeleted() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("iptvmac-db-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let path = dir.appendingPathComponent("t.sqlite").path
    try Data("this is not a database, just text that is long enough to look like a header".utf8 + Data(count: 4096)).write(to: URL(fileURLWithPath: path))
    let r = try AppDatabase.openRecovering(path: path)
    let aside = try #require(r.movedAside)
    #expect(FileManager.default.fileExists(atPath: aside))
    #expect(try r.db.dbQueue.read { try Account.fetchCount($0) } == 0)
}

@Test func iconUrlsPointingAtTheLocalNetworkAreNotFetched() {
    func icon(_ s: String) -> URL? { Item(accountId: 1, type: .live, name: "x", streamId: "1", icon: s).iconURL }
    #expect(icon("https://cdn.example.com/logo.png") != nil)
    #expect(icon("http://192.168.1.1/cgi-bin/reboot") == nil)
    #expect(icon("http://10.0.0.5/x.png") == nil)
    #expect(icon("http://172.20.1.1/x.png") == nil)
    #expect(icon("http://localhost:8123/api/webhook/x") == nil)
    #expect(icon("http://homeassistant.local:8123/x") == nil)
    #expect(icon("http://169.254.1.1/x") == nil)
    #expect(icon("file:///etc/passwd") == nil)
    #expect(icon("data:text/html,hi") == nil)
}
