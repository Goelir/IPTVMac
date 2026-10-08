import Testing
import Foundation
import GRDB
@testable import IPTVCore

// Network side, with the mocked URLProtocol (MockURLProtocol.handler is global: lives in the serialized SyncTests suite).

extension SyncTests {
    private static let vodJSON = #"{"info":{"movie_image":"https://img.example.com/p.jpg","plot":"A heist.","genre":"Action","rating":"7.5","duration_secs":6300,"youtube_trailer":"dQw4w9WgXcQ"},"movie_data":{"stream_id":10,"name":"Heist"},"user_info":{"password":"pw"}}"#
    private static let seriesJSON = #"{"seasons":[],"info":{"name":"The Show","cover":"https://c.example.com/s.jpg","plot":"Secrets.","releaseDate":"2021-02-01","episode_run_time":"45"},"episodes":{"1":[{"id":"501","episode_num":1,"title":"Pilot","season":1}]}}"#

    private func params(_ r: URLRequest) -> [String: String] {
        Dictionary(uniqueKeysWithValues: (URLComponents(url: r.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    }

    @Test func vodInfoAsksGetVodInfoWithTheVodId() async throws {
        let urls = XtreamURLs(server: "h", username: "u", password: "p")!
        nonisolated(unsafe) var seen: [String: String] = [:]
        MockURLProtocol.handler = { r in seen = self.params(r); return (200, Data(Self.vodJSON.utf8)) }
        let i = try await XtreamClient(urls: urls, session: mockSession()).vodInfo(streamId: "10")
        #expect(seen["action"] == "get_vod_info"); #expect(seen["vod_id"] == "10")
        #expect(i.plot == "A heist."); #expect(i.rating == 7.5); #expect(i.durationMinutes == 105); #expect(i.trailerID == "dQw4w9WgXcQ")
    }

    @Test func seriesInfoAsksGetSeriesInfoWithTheSeriesId() async throws {
        let urls = XtreamURLs(server: "h", username: "u", password: "p")!
        nonisolated(unsafe) var seen: [String: String] = [:]
        MockURLProtocol.handler = { r in seen = self.params(r); return (200, Data(Self.seriesJSON.utf8)) }
        let i = try await XtreamClient(urls: urls, session: mockSession()).seriesInfo(seriesId: "20")
        #expect(seen["action"] == "get_series_info"); #expect(seen["series_id"] == "20")
        #expect(i.title == "The Show"); #expect(i.year == 2021); #expect(i.durationMinutes == 45)
    }

    @Test func aTitleTheProviderKnowsNothingAboutIsEmptyNotAnError() async throws {
        let urls = XtreamURLs(server: "h", username: "u", password: "p")!
        let c = XtreamClient(urls: urls, session: mockSession())
        for body in ["[]", "null", "false", #"{"info":[],"movie_data":[]}"#, ""] {
            MockURLProtocol.handler = { _ in (200, Data(body.utf8)) }
            #expect(try await c.vodInfo(streamId: "1").hasContent == false, "body \(body)")
        }
    }

    @Test func infoRequestFailuresAreErrors() async throws {
        let urls = XtreamURLs(server: "h", username: "u", password: "p")!
        let c = XtreamClient(urls: urls, session: mockSession())
        MockURLProtocol.handler = { _ in (500, Data()) }
        await #expect(throws: IPTVError.http(500)) { try await c.vodInfo(streamId: "1") }
        MockURLProtocol.handler = { _ in (200, Data("<html>blocked</html>".utf8)) }
        await #expect(throws: IPTVError.badResponse) { try await c.seriesInfo(seriesId: "1") }
    }

    @Test func infoIsFetchedOnceThenServedFromTheCache() async throws {
        let db = try AppDatabase(); let a = try account(db)
        let svc = SyncService(db: db, session: mockSession())
        nonisolated(unsafe) var calls = 0
        MockURLProtocol.handler = { _ in calls += 1; return (200, Data(Self.vodJSON.utf8)) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let first = try await svc.info(account: a, password: "p", type: .movie, streamId: "10", now: now)
        #expect(first.plot == "A heist."); #expect(calls == 1)

        MockURLProtocol.handler = { _ in calls += 1; return (500, Data()) }
        #expect(try await svc.info(account: a, password: "p", type: .movie, streamId: "10", now: now.addingTimeInterval(13 * 86_400)) == first)
        #expect(calls == 1)                                                              // cache hit: no request

        MockURLProtocol.handler = { _ in calls += 1; return (200, Data(Self.vodJSON.replacingOccurrences(of: "A heist.", with: "Newer.").utf8)) }
        #expect(try await svc.info(account: a, password: "p", type: .movie, streamId: "10", now: now.addingTimeInterval(15 * 86_400)).plot == "Newer.")
        #expect(calls == 2)                                                              // expired: fetched again
        #expect(try await svc.info(account: a, password: "p", type: .movie, streamId: "10", now: now.addingTimeInterval(15 * 86_400), refresh: true).plot == "Newer.")
        #expect(calls == 3)                                                              // refresh ignores the cache
    }

    @Test func aFailedFetchFallsBackToAStaleCopyButWithoutOneItThrows() async throws {
        let db = try AppDatabase(); let a = try account(db)
        let svc = SyncService(db: db, session: mockSession())
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        MockURLProtocol.handler = { _ in (500, Data()) }
        await #expect(throws: IPTVError.http(500)) { try await svc.info(account: a, password: "p", type: .movie, streamId: "10", now: now) }
        MockURLProtocol.handler = { _ in (200, Data(Self.vodJSON.utf8)) }
        let good = try await svc.info(account: a, password: "p", type: .movie, streamId: "10", now: now)
        MockURLProtocol.handler = { _ in (500, Data()) }                                 // offline a month later
        #expect(try await svc.info(account: a, password: "p", type: .movie, streamId: "10", now: now.addingTimeInterval(30 * 86_400)) == good)
    }

    @Test func emptyAnswersAreNotCachedSoReopeningTriesAgain() async throws {
        let db = try AppDatabase(); let a = try account(db)
        let svc = SyncService(db: db, session: mockSession())
        nonisolated(unsafe) var calls = 0
        MockURLProtocol.handler = { _ in calls += 1; return (200, Data(#"{"info":[]}"#.utf8)) }
        #expect(try await svc.info(account: a, password: "p", type: .movie, streamId: "10").hasContent == false)
        #expect(try await svc.info(account: a, password: "p", type: .movie, streamId: "10").hasContent == false)
        #expect(calls == 2)
        #expect(try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT count(*) FROM item_info") } == 0)
    }

    @Test func m3uAndLiveItemsNeverTouchTheNetworkOrTheCache() async throws {
        let db = try AppDatabase()
        let m3u = try await db.dbQueue.write { d in var x = Account(name: "m", kind: .m3u, url: "http://h/l.m3u"); try x.insert(d); return x }
        let x = try account(db)
        let svc = SyncService(db: db, session: mockSession())
        nonisolated(unsafe) var calls = 0
        MockURLProtocol.handler = { _ in calls += 1; return (200, Data(Self.vodJSON.utf8)) }
        #expect(try await svc.info(account: m3u, password: nil, type: .movie, streamId: "http://h/a.mp4").hasContent == false)
        #expect(try await svc.info(account: x, password: "p", type: .live, streamId: "1").hasContent == false)
        #expect(calls == 0)
        #expect(try await db.dbQueue.read { try Int.fetchOne($0, sql: "SELECT count(*) FROM item_info") } == 0)
    }

    @Test func theInfoRequestNeverCarriesCredentialsIntoTheCache() async throws {
        let db = try AppDatabase(); let a = try account(db)
        MockURLProtocol.handler = { _ in (200, Data(Self.vodJSON.utf8)) }               // the response even echoes a password
        _ = try await SyncService(db: db, session: mockSession()).info(account: a, password: "pw", type: .movie, streamId: "10")
        let stored = try #require(try await db.dbQueue.read { try String.fetchOne($0, sql: "SELECT json FROM item_info") })
        #expect(!stored.contains("pw")); #expect(!stored.contains("password"))
    }

    @Test func loadingEpisodesAlsoFillsTheSeriesInfoCacheWithoutASecondRequest() async throws {
        let db = try AppDatabase(); let a = try account(db)
        let svc = SyncService(db: db, session: mockSession())
        nonisolated(unsafe) var calls = 0
        MockURLProtocol.handler = { _ in calls += 1; return (200, Data(Self.seriesJSON.utf8)) }
        let eps = try await svc.episodes(account: a, password: "p", seriesId: "20")
        #expect(eps.count == 1); #expect(calls == 1)
        let info = try await svc.info(account: a, password: "p", type: .series, streamId: "20")
        #expect(info.plot == "Secrets."); #expect(info.year == 2021)
        #expect(calls == 1)                                                              // the episodes request already carried it
    }
}
