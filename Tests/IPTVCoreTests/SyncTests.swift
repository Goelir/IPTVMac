import Testing
import Foundation
import GRDB
@testable import IPTVCore

@Suite(.serialized) struct SyncTests {
    let live1 = #"[{"stream_id":1,"name":"News 24","stream_icon":"http://i/1.png","category_id":"5","tv_archive":1,"tv_archive_duration":"3","epg_channel_id":"n24"},{"stream_id":2,"name":"Sport","category_id":5}]"#
    let vod = #"[{"stream_id":10,"name":"Big Movie","rating":"","category_id":"7","container_extension":"mkv"},{"stream_id":11,"name":"Other","rating":7.5,"category_id":null},{"name":"NoId"}]"#
    let seriesJSON = #"[{"series_id":20,"name":"The Show","cover":"http://c/20.jpg","rating":null,"category_id":"8"}]"#

    func body(_ action: String, live: String? = nil) -> String {
        switch action {
        case "get_live_categories": return #"[{"category_id":"5","category_name":"News"}]"#
        case "get_vod_categories": return #"[{"category_id":7,"category_name":"Action"}]"#
        case "get_series_categories": return #"[{"category_id":"8","category_name":"Drama"}]"#
        case "get_live_streams": return live ?? live1
        case "get_vod_streams": return vod
        case "get_series": return seriesJSON
        default: return #"{"user_info":{"auth":1},"server_info":{}}"#
        }
    }

    func account(_ db: AppDatabase) throws -> Account {
        try db.dbQueue.write { d in var a = Account(name: "x", kind: .xtream, server: "http://h", username: "u"); try a.insert(d); return a }
    }

    @Test func syncsMixedTypeJSON() async throws {
        let db = try AppDatabase(); let a = try account(db)
        MockURLProtocol.handler = { r in (200, Data(self.body(actionOf(r)).utf8)) }
        try await SyncService(db: db, session: mockSession()).sync(account: a, password: "p")
        let (n, cats, news) = try await db.dbQueue.read { d in
            (try Item.fetchAll(d), try Category.fetchAll(d), try Search.run(d, .init(accountId: a.id!, text: "news")))
        }
        #expect(n.count == 5)                       // "NoId" skipped
        #expect(cats.count == 3)
        #expect(cats.first { $0.type == .movie }?.remoteId == "7")
        #expect(news.first?.tvArchive == true); #expect(news.first?.archiveDays == 3)
        #expect(n.first { $0.name == "Sport" }?.categoryId == "5")
        #expect(n.first { $0.name == "Big Movie" }?.containerExt == "mkv")
        #expect(n.first { $0.name == "Other" }?.rating == "7.5")
    }

    @Test func resyncDropsRemovedItemsButKeepsFavorites() async throws {
        let db = try AppDatabase(); let a = try account(db)
        MockURLProtocol.handler = { r in (200, Data(self.body(actionOf(r)).utf8)) }
        let svc = SyncService(db: db, session: mockSession())
        try await svc.sync(account: a, password: "p")
        try await db.dbQueue.write { d in try d.execute(sql: "INSERT INTO favorite VALUES (?, 'live', '2')", arguments: [a.id!]) }
        let only1 = #"[{"stream_id":1,"name":"News 24","category_id":"5"}]"#
        MockURLProtocol.handler = { r in (200, Data(self.body(actionOf(r), live: only1).utf8)) }
        try await svc.sync(account: a, password: "p")
        let names = try await db.dbQueue.read { try Item.filter(Column("type") == "live").fetchAll($0).map(\.name) }
        #expect(names == ["News 24"])
        let fav = try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT count(*) FROM favorite") }
        #expect(fav == 1)
    }

    @Test func failedSyncLeavesCacheUntouched() async throws {
        let db = try AppDatabase(); let a = try account(db)
        MockURLProtocol.handler = { r in (200, Data(self.body(actionOf(r)).utf8)) }
        let svc = SyncService(db: db, session: mockSession())
        try await svc.sync(account: a, password: "p")
        for bad in [(500, "oops"), (200, "<html>blocked</html>"), (200, #"{"error":"x"}"#)] {
            MockURLProtocol.handler = { _ in (bad.0, Data(bad.1.utf8)) }
            await #expect(throws: (any Error).self) { try await svc.sync(account: a, password: "p") }
        }
        let count = try await db.dbQueue.read { try Item.fetchCount($0) }
        #expect(count == 5)
    }

    @Test func authenticateReportsBadCredentials() async throws {
        let urls = XtreamURLs(server: "h", username: "u", password: "p")!
        MockURLProtocol.handler = { _ in (200, Data(#"{"user_info":{"auth":0}}"#.utf8)) }
        await #expect(throws: IPTVError.badCredentials) { try await XtreamClient(urls: urls, session: mockSession()).authenticate() }
        MockURLProtocol.handler = { _ in (200, Data(#"{"user_info":{"auth":"1"}}"#.utf8)) }
        try await XtreamClient(urls: urls, session: mockSession()).authenticate()
    }

    @Test func epgTitlesAreBase64Decoded() async throws {
        let urls = XtreamURLs(server: "h", username: "u", password: "p")!
        let t = Data("Evening News".utf8).base64EncodedString()
        MockURLProtocol.handler = { _ in
            (200, Data(#"{"epg_listings":[{"title":"\#(t)","start_timestamp":"1700000000","stop_timestamp":"1700003600"}]}"#.utf8))
        }
        let c = XtreamClient(urls: urls, session: mockSession())
        #expect(try await c.epgNow(streamId: "1") == "Evening News")
        #expect(try await c.epgShort(streamId: "1", limit: 3).map(\.title) == ["Evening News"])
        let arch = try await c.epgArchive(streamId: "1")
        #expect(arch == [EPGEntry(title: "Evening News", start: Date(timeIntervalSince1970: 1_700_000_000), end: Date(timeIntervalSince1970: 1_700_003_600))])
    }

    @Test func episodesAreFetchedStoredAndServedFromCacheOffline() async throws {
        let db = try AppDatabase(); let a = try account(db)
        let info = #"{"episodes":{"1":[{"id":"501","episode_num":1,"title":"Pilot","container_extension":"mkv","season":1},{"id":502,"episode_num":"2","title":"Two","season":1}],"2":[{"id":"601","episode_num":1,"title":"Back","season":2}]}}"#
        MockURLProtocol.handler = { _ in (200, Data(info.utf8)) }
        let svc = SyncService(db: db, session: mockSession())
        let eps = try await svc.episodes(account: a, password: "p", seriesId: "20")
        #expect(eps.map(\.title) == ["Pilot", "Two", "Back"])
        MockURLProtocol.handler = { _ in (500, Data()) }
        let cached = try await svc.episodes(account: a, password: "p", seriesId: "20")
        #expect(cached.count == 3)
    }

    // MARK: Final-review fixes

    @Test func syncReportsBadCredentialsWhenAuthIsZero() async throws {
        let db = try AppDatabase(); let a = try account(db)
        MockURLProtocol.handler = { r in
            actionOf(r).isEmpty ? (200, Data(#"{"user_info":{"auth":0}}"#.utf8)) : (200, Data(self.body(actionOf(r)).utf8))
        }
        await #expect(throws: IPTVError.badCredentials) {
            try await SyncService(db: db, session: mockSession()).sync(account: a, password: "wrong")
        }
    }

    @Test func emptyServerResponseDoesNotWipeExistingCache() async throws {
        let db = try AppDatabase(); let a = try account(db)
        let svc = SyncService(db: db, session: mockSession())
        MockURLProtocol.handler = { r in (200, Data(self.body(actionOf(r)).utf8)) }
        try await svc.sync(account: a, password: "p")
        MockURLProtocol.handler = { r in
            actionOf(r).isEmpty ? (200, Data(#"{"user_info":{"auth":1}}"#.utf8)) : (200, Data("[]".utf8))
        }
        await #expect(throws: IPTVError.emptyResponse) { try await svc.sync(account: a, password: "p") }
        #expect(try await db.dbQueue.read { try Item.fetchCount($0) } == 5)
    }

    @Test func m3uCatchupAttributeDoesNotShowACatchupButton() async throws {
        let db = try AppDatabase()
        var a = Account(name: "m", kind: .m3u, url: "http://h/list.m3u")
        a = try await db.dbQueue.write { d in var x = a; try x.insert(d); return x }
        let pl = "#EXTM3U\n#EXTINF:-1 catchup-days=\"3\" group-title=\"News\",One\nhttp://h/live/1.ts\n"
        MockURLProtocol.handler = { _ in (200, Data(pl.utf8)) }
        try await SyncService(db: db, session: mockSession()).sync(account: a, password: nil)
        let item = try await db.dbQueue.read { try Item.fetchOne($0) }
        #expect(item?.tvArchive == false)   // catch-up URLs can only be built for Xtream accounts
    }

    @Test func serverTimeZoneIsReadFromServerInfo() async throws {
        let urls = XtreamURLs(server: "h", username: "u", password: "p")!
        MockURLProtocol.handler = { _ in (200, Data(#"{"user_info":{"auth":1},"server_info":{"timezone":"Europe/Paris"}}"#.utf8)) }
        let c = XtreamClient(urls: urls, session: mockSession())
        #expect(await c.serverTimeZone() == TimeZone(identifier: "Europe/Paris"))
        MockURLProtocol.handler = { _ in (200, Data(#"{"user_info":{"auth":1},"server_info":{"timezone":"Not/AZone"}}"#.utf8)) }
        #expect(await c.serverTimeZone() == nil)
        MockURLProtocol.handler = { _ in (500, Data()) }
        #expect(await c.serverTimeZone() == nil)
    }
}
