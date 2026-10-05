import Testing
import Foundation
import GRDB
@testable import IPTVCore

// Same suite as SyncTests: MockURLProtocol.handler is global, so network tests must run serially together.
extension SyncTests {
    var playlist: String { """
    \u{FEFF}#EXTM3U\r
    #EXTINF:-1 tvg-id="n" group-title="News" tvg-logo="http://l/1.png",News One\r
    http://h/live/1.ts\r
    #EXTINF:-1 group-title="Movies",Big Film\r
    #EXTVLCOPT:network-caching=1000\r
    http://h/movie/u/p/9.mkv\r
    #EXTINF:-1 group-title="Series",Show S01E01\r
    http://h/series/u/p/5.mp4\r
    """ }

    func m3uAccount(_ db: AppDatabase) throws -> Account {
        try db.dbQueue.write { d in var a = Account(name: "m", kind: .m3u, url: "http://h/list.m3u"); try a.insert(d); return a }
    }

    @Test func importsClassifiesAndBuildsCategories() async throws {
        let db = try AppDatabase(); let a = try m3uAccount(db)
        MockURLProtocol.handler = { _ in (200, Data(self.playlist.utf8)) }
        try await SyncService(db: db, session: mockSession()).sync(account: a, password: nil)
        let items = try await db.dbQueue.read { try Item.fetchAll($0) }
        #expect(items.count == 3)
        #expect(items.first { $0.name == "News One" }?.type == .live)
        #expect(items.first { $0.name == "Big Film" }?.type == .movie)
        #expect(items.first { $0.name == "Show S01E01" }?.type == .series)
        #expect(items.first { $0.name == "Big Film" }?.directURL == "http://h/movie/u/p/9.mkv")
        let cats = try await db.dbQueue.read { try Category.fetchAll($0) }
        #expect(Set(cats.map(\.name)) == ["News", "Movies", "Series"])
    }

    @Test func htmlErrorPageIsRejectedAndCacheKept() async throws {
        let db = try AppDatabase(); let a = try m3uAccount(db)
        let svc = SyncService(db: db, session: mockSession())
        MockURLProtocol.handler = { _ in (200, Data(self.playlist.utf8)) }
        try await svc.sync(account: a, password: nil)
        MockURLProtocol.handler = { _ in (200, Data("<html>Access denied</html>".utf8)) }
        await #expect(throws: IPTVError.badResponse) { try await svc.sync(account: a, password: nil) }
        MockURLProtocol.handler = { _ in (403, Data()) }
        await #expect(throws: IPTVError.http(403)) { try await svc.sync(account: a, password: nil) }
        #expect(try await db.dbQueue.read { try Item.fetchCount($0) } == 3)
    }

    @Test func invalidLinkIsBadConfig() async throws {
        let db = try AppDatabase()
        var a = Account(name: "m", kind: .m3u, url: "not a url")
        try await db.dbQueue.write { try a.insert($0) }
        await #expect(throws: IPTVError.badConfig) { try await SyncService(db: db, session: mockSession()).sync(account: a, password: nil) }
    }
}
