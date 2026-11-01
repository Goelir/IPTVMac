import Testing
import Foundation
import GRDB
import IPTVCore
@testable import IPTVAppKit

// The logic behind the iPhone/iPad screens: the keychain store (with a fake keychain), the add-source form, recent searches, resume points.

private final class FakeKeychain: KeychainBacking {
    var items: [String: String] = [:]
    var failReads = false, failWrites = false
    func read(_ key: String) throws -> String? { if failReads { throw KeychainError(status: -25308) }; return items[key] }
    func write(_ value: String, key: String) throws { if failWrites { throw KeychainError(status: -25308) }; items[key] = value }
    func delete(_ key: String) { items[key] = nil }
}

@Test func keychainStoreKeepsPasswordsIncludingNone() throws {
    let k = FakeKeychain(), s = KeychainSecretStore(backing: k)
    #expect(s.password(for: 1) == nil)
    try s.setPassword("pw", for: 1); try s.setPassword("", for: 2)
    #expect(s.password(for: 1) == "pw" && s.password(for: 2) == "")        // "" = deliberately no password, not "missing"
    #expect(KeychainSecretStore(backing: k).password(for: 2) == "")        // survives a new store (a relaunch)
    s.deletePassword(for: 1)
    #expect(s.password(for: 1) == nil && k.items["account-1"] == nil)
}

@Test func keychainStoreDoesNotCacheAFailedRead() throws {
    let k = FakeKeychain(); k.items["account-3"] = "v1:secret"
    let s = KeychainSecretStore(backing: k)
    k.failReads = true
    #expect(s.password(for: 3) == nil)
    k.failReads = false
    #expect(s.password(for: 3) == "secret")                                // an unreadable keychain must not look like "no password"
}

@Test func keychainStoreMovesAPasswordOutOfTheDatabase() throws {
    let db = try AppDatabase()
    let ids = try db.dbQueue.write { d -> [Int64] in
        var a = Account(name: "a", kind: .xtream, server: "h", username: "u"), b = Account(name: "b", kind: .xtream, server: "h", username: "v")
        try a.insert(d); try b.insert(d); return [a.id!, b.id!]
    }
    let id = ids[0]
    let legacy = DatabaseSecretStore(db: db)
    try legacy.setPassword("old", for: id)
    let k = FakeKeychain(), s = KeychainSecretStore(backing: k, legacy: legacy)
    #expect(s.password(for: id) == "old")
    #expect(k.items["account-\(id)"] == "v1:old")
    #expect((try db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM secret") }) == 0)   // the plain-text copy is gone
    k.failWrites = true
    let id2 = ids[1]
    try legacy.setPassword("kept", for: id2)
    #expect(KeychainSecretStore(backing: k, legacy: legacy).password(for: id2) == "kept")             // a keychain that refuses leaves the old copy alone
    #expect((try db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM secret") }) == 1)
}

@Test func sourceDraftValidatesWhileTyping() {
    var d = SourceDraft()
    #expect(!d.isComplete && !d.canTest)
    d.name = "Home"; d.server = "host:8080"; d.username = "u"
    #expect(d.isComplete && d.canTest && !d.serverLooksWrong)               // a bare host:port is fine, http:// is added
    d.server = "http://bad host"
    #expect(d.serverLooksWrong && !d.canTest)
    d.kind = .m3u; d.url = "example.com/list.m3u"
    #expect(d.isComplete && d.urlLooksWrong && !d.canTest)                  // a playlist link needs its scheme
    d.url = "https://example.com/list.m3u"
    #expect(d.canTest)
    d.url = "file:///etc/passwd"
    #expect(d.urlLooksWrong)
    let (a, pw) = { var x = SourceDraft(); x.name = " Home "; x.server = " h:1 "; x.username = "u"; x.password = "p"; return x.makeAccount() }()
    #expect(a.name == "Home" && a.server == "h:1" && pw == "p")
}

@Test func aPastedProviderLinkYieldsTheXtreamLogin() {
    let l = SourceDraft.xtreamLogin(inLink: " http://host.tv:8080/get.php?username=bob&password=p%40ss&type=m3u_plus&output=ts ")
    #expect(l?.server == "http://host.tv:8080" && l?.username == "bob" && l?.password == "p@ss")
    #expect(SourceDraft.xtreamLogin(inLink: "http://host.tv/list.m3u") == nil)
    #expect(SourceDraft.xtreamLogin(inLink: "not a link") == nil)
}

@Test func recentSearchesAreNewestFirstDeduplicatedAndCapped() {
    let d = UserDefaults(suiteName: "recent-\(UUID())")!
    let r = RecentSearches(defaults: d)
    r.add("a"); r.add("  "); #expect(r.items.isEmpty)                         // too short to be worth keeping
    for t in ["news", "movie", "News", "kids"] { r.add(t) }
    #expect(r.items == ["kids", "News", "movie"])
    for i in 0..<20 { r.add("term \(i)") }
    #expect(r.items.count == RecentSearches.limit && r.items.first == "term 19")
    r.remove("term 19"); #expect(!r.items.contains("term 19"))
    r.clear(); #expect(r.items.isEmpty)
}

@Test func continueEntriesCarryProgressAndTheLastEpisode() throws {
    let db = try AppDatabase()
    try db.dbQueue.write { d in
        var a = Account(name: "a", kind: .xtream, server: "h", username: "u"); try a.insert(d)
        var m = Item(accountId: a.id!, type: .movie, name: "M", streamId: "10"); try m.insert(d)
        var s = Item(accountId: a.id!, type: .series, name: "S", streamId: "20"); try s.insert(d)
        for (sn, n, sid) in [(1, 1, "101"), (1, 2, "102"), (2, 1, "201")] { var e = Episode(accountId: a.id!, seriesId: "20", season: sn, number: n, title: "e", streamId: sid); try e.insert(d) }
        try UserData.saveProgress(d, accountId: a.id!, type: .movie, streamId: "10", position: 30, duration: 120)
        try UserData.saveProgress(d, accountId: a.id!, type: .series, streamId: "ep:101", position: 99, duration: 100)
        try UserData.saveProgress(d, accountId: a.id!, type: .series, streamId: "ep:102", position: 10, duration: 100)
        try d.execute(sql: "UPDATE history SET updated = datetime('now', '-1 hour') WHERE streamId = 'ep:101'")   // saves in one second tie
    }
    let aid = try db.dbQueue.read { try Int64.fetchOne($0, sql: "SELECT id FROM account")! }
    let movies = try db.dbQueue.read { try WatchProgress.continueEntries($0, accountId: aid, type: .movie) }
    #expect(movies.count == 1 && movies[0].fraction == 0.25)
    let series = try db.dbQueue.read { try WatchProgress.continueEntries($0, accountId: aid, type: .series) }
    #expect(series.count == 1 && series[0].season == 1 && series[0].episode == 2 && series[0].fraction == 0.1)
    #expect(series[0].episodeId == "102" && series[0].position == 10 && series[0].duration == 100 && series[0].secondsLeft == 90)   // where it was left
    #expect(movies[0].episodeId == nil && movies[0].secondsLeft == 90)
    let eps = try db.dbQueue.read { try WatchProgress.cachedEpisodes($0, accountId: aid, seriesId: "20") }
    #expect(eps.map(\.streamId) == ["101", "102", "201"])                                                 // watching order
}

@Test func theCaptionSaysWhereAnEpisodeWasLeft() {
    let item = Item(accountId: 1, type: .series, name: "S", streamId: "20")
    func cap(_ e: ContinueEntry) -> String? { e.caption(episode: "S%d E%d", left: "%@ left", minutes: "%d min") }
    #expect(cap(ContinueEntry(item: item, season: 2, episode: 5, position: 600, duration: 2400)) == "S2 E5 · 30 min left")
    #expect(cap(ContinueEntry(item: item, position: 100, duration: 160)) == "1 min left")          // under a minute counts as one, never 0
    #expect(cap(ContinueEntry(item: item, season: 1, episode: 1)) == "S1 E1")                       // no length known: only the episode
    #expect(cap(ContinueEntry(item: item)) == nil)
}

@Test func upNextResumesHalfWatchedThenMovesOn() {
    let eps = [(1, 1, "a"), (1, 2, "b"), (2, 1, "c")].map { Episode(accountId: 1, seriesId: "s", season: $0.0, number: $0.1, title: "t", streamId: $0.2) }
    #expect(WatchProgress.upNext(eps, progress: [:])?.episode.streamId == "a")                               // nothing watched: the first
    func p(_ pos: Double, _ rank: Int) -> EpisodeProgress { EpisodeProgress(position: pos, duration: 100, rank: rank) }
    var r = WatchProgress.upNext(eps, progress: ["a": p(99, 0), "b": p(40, 1)])
    #expect(r?.episode.streamId == "b" && r?.resume == true)                                                  // left halfway: resume it
    r = WatchProgress.upNext(eps, progress: ["a": p(99, 0), "b": p(98, 1)])
    #expect(r?.episode.streamId == "c" && r?.resume == false)                                                 // finished: the next one, across seasons
    #expect(WatchProgress.upNext(eps, progress: ["c": p(99, 2)]) == nil)                                      // the last one was finished
    r = WatchProgress.upNext(eps, progress: ["b": p(2, 0)])
    #expect(r?.episode.streamId == "c")                                                                       // under 5 s is not a resume point: moves on
    #expect(WatchProgress.upNext([], progress: [:]) == nil)
}
