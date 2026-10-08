import Foundation
import GRDB

public final class SyncService {
    let db: AppDatabase
    let session: URLSession
    public init(db: AppDatabase, session: URLSession = apiSession) { self.db = db; self.session = session }

    public func sync(account: Account, password: String?) async throws {
        guard let aid = account.id else { throw IPTVError.badConfig }
        let (cats, items): ([Category], [Item])
        switch account.kind {
        case .xtream: (cats, items) = try await fetchXtream(account, aid, password ?? "")
        case .m3u: (cats, items) = try await fetchM3U(account, aid)
        }
        if items.isEmpty { throw IPTVError.emptyResponse }   // expired subscription / overloaded panel / nothing there: keep what we have
        // Only the types that came back with items are replaced: a panel that answers [] for one section while it rebuilds its
        // cache must not wipe that section (and the favorites that point into it).
        let types = Set(items.map(\.type)).map(\.rawValue)
        let typeList = types.map { "'\($0)'" }.joined(separator: ",")      // raw values of our own enum, not user input
        try await db.dbQueue.write { d in
            try d.execute(sql: "UPDATE item SET stale = 1 WHERE accountId = ? AND type IN (\(typeList))", arguments: [aid])
            try d.execute(sql: "DELETE FROM category WHERE accountId = ? AND type IN (\(typeList))", arguments: [aid])
            for var c in cats { try c.insert(d, onConflict: .ignore) }
            let st = try d.cachedStatement(sql: """
                INSERT INTO item (accountId,type,name,categoryId,icon,rating,streamId,containerExt,directURL,tvArchive,archiveDays,epgChannelId,stale)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?,0)
                ON CONFLICT(accountId,type,streamId) DO UPDATE SET
                  name=excluded.name, categoryId=excluded.categoryId, icon=excluded.icon, rating=excluded.rating,
                  containerExt=excluded.containerExt, directURL=excluded.directURL, tvArchive=excluded.tvArchive,
                  archiveDays=excluded.archiveDays, epgChannelId=excluded.epgChannelId, stale=0
                """)
            for i in items {
                try st.execute(arguments: [aid, i.type.rawValue, i.name, i.categoryId, i.icon, i.rating, i.streamId,
                                           i.containerExt, i.directURL, i.tvArchive, i.archiveDays, i.epgChannelId])
            }
            try d.execute(sql: "DELETE FROM item WHERE accountId = ? AND stale = 1", arguments: [aid])
        }
    }

    /// Provider-controlled size limit: a list this large is a broken or hostile response, not a catalog.
    static let maxResponseBytes = 300_000_000

    // MARK: Xtream

    private func fetchXtream(_ account: Account, _ aid: Int64, _ password: String) async throws -> ([Category], [Item]) {
        guard let urls = XtreamURLs(server: account.server ?? "", username: account.username ?? "", password: password)
        else { throw IPTVError.badConfig }
        let client = XtreamClient(urls: urls, session: session)
        try await client.authenticate()
        async let l = fetchType(client, .live)
        async let m = fetchType(client, .movie)
        async let s = fetchType(client, .series)
        var cats: [Category] = [], items: [Item] = []
        for (type, rawCats, rawStreams) in try await [l, m, s] {
            for c in rawCats {
                guard let id = str(c["category_id"]) else { continue }
                cats.append(Category(accountId: aid, type: type, remoteId: id, name: str(c["category_name"]) ?? id))
            }
            for d in rawStreams {
                let idKey = type == .series ? "series_id" : "stream_id"
                guard let sid = str(d[idKey]) else { continue }
                items.append(Item(
                    accountId: aid, type: type, name: str(d["name"]) ?? sid, streamId: sid,
                    categoryId: str(d["category_id"]),
                    icon: str(type == .series ? d["cover"] : d["stream_icon"]),
                    rating: str(d["rating"]), containerExt: str(d["container_extension"]),
                    tvArchive: int(d["tv_archive"]) == 1, archiveDays: int(d["tv_archive_duration"]) ?? 0,
                    epgChannelId: str(d["epg_channel_id"])))
            }
        }
        return (cats, items)
    }

    private func fetchType(_ c: XtreamClient, _ t: ItemType) async throws -> (ItemType, [[String: Any]], [[String: Any]]) {
        let (ca, sa): (String, String) = switch t {
        case .live: ("get_live_categories", "get_live_streams")
        case .movie: ("get_vod_categories", "get_vod_streams")
        case .series: ("get_series_categories", "get_series")
        }
        async let cats = c.array(ca)
        async let streams = c.array(sa)
        return (t, try await cats, try await streams)
    }

    // MARK: M3U

    // ponytail: whole playlist held in memory; switch to a streamed download if lists above ~100 MB show up.
    private func fetchM3U(_ account: Account, _ aid: Int64) async throws -> ([Category], [Item]) {
        guard let s = account.url?.trimmingCharacters(in: .whitespacesAndNewlines), let url = URL(string: s),
              url.scheme != nil, url.host != nil else { throw IPTVError.badConfig }
        let (data, resp) = try await session.data(from: url)
        if let code = (resp as? HTTPURLResponse)?.statusCode, !(200..<300).contains(code) { throw IPTVError.http(code) }
        guard data.count <= Self.maxResponseBytes else { throw IPTVError.badResponse }
        let text = String(decoding: data, as: UTF8.self)
        let first = text.drop { $0.isWhitespace || $0 == "\u{FEFF}" }
        guard first.hasPrefix("#EXTM3U") else { throw IPTVError.badResponse }

        var parser = M3UParser()
        var items: [Item] = [], seenCats = Set<String>(), cats: [Category] = [], seenItems = Set<String>()
        for line in text.split(whereSeparator: \.isNewline) {
            guard let e = parser.feed(String(line)) else { continue }
            // ponytail: no catch-up for M3U (timeshift URLs are Xtream-only); the attribute is ignored on purpose.
            let type = M3UClassifier.type(url: e.url, group: e.group)
            guard seenItems.insert("\(type.rawValue)|\(e.url)").inserted else { continue }   // same URL in two groups: the first group keeps it
            if let g = e.group, seenCats.insert("\(type.rawValue)|\(g)").inserted {
                cats.append(Category(accountId: aid, type: type, remoteId: g, name: g))
            }
            items.append(Item(accountId: aid, type: type, name: e.name, streamId: e.url, categoryId: e.group,
                              icon: e.logo, directURL: e.url, tvArchive: false, archiveDays: 0, epgChannelId: e.tvgId))
        }
        return (cats, items)
    }

    // MARK: Episodes

    public func episodes(account: Account, password: String?, seriesId: String) async throws -> [Episode] {
        guard let aid = account.id else { throw IPTVError.badConfig }
        func cached() throws -> [Episode] {
            try db.dbQueue.read {
                try Episode.filter(Column("accountId") == aid && Column("seriesId") == seriesId)
                    .order(Column("season"), Column("number")).fetchAll($0)
            }
        }
        guard let urls = XtreamURLs(server: account.server ?? "", username: account.username ?? "", password: password ?? "")
        else { return try cached() }
        do {
            let info = try await XtreamClient(urls: urls, session: session).rawSeriesInfo(seriesId)
            var raw: [[String: Any]] = []
            if let dict = info["episodes"] as? [String: Any] {
                for k in dict.keys.sorted(by: { (Int($0) ?? 0) < (Int($1) ?? 0) }) { raw += dict[k] as? [[String: Any]] ?? [] }
            } else if let arr = info["episodes"] as? [[Any]] {
                for s in arr { raw += s.compactMap { $0 as? [String: Any] } }
            } else { throw IPTVError.badResponse }
            let eps = raw.compactMap { d -> Episode? in
                guard let id = str(d["id"]) else { return nil }
                return Episode(accountId: aid, seriesId: seriesId, season: int(d["season"]) ?? 1,
                               number: int(d["episode_num"]) ?? 0, title: str(d["title"]) ?? "Episode \(int(d["episode_num"]) ?? 0)",
                               streamId: id, containerExt: str(d["container_extension"]))
            }
            let details = ItemInfo(response: info)     // the same response also carries the series details
            try await db.dbQueue.write { d in
                if details.hasContent { try ItemInfoStore.save(d, accountId: aid, type: .series, streamId: seriesId, info: details) }
                if !eps.isEmpty {   // episodes the provider no longer lists must not be served from the cache
                    let ids = String(decoding: try JSONEncoder().encode(eps.map(\.streamId)), as: UTF8.self)
                    try d.execute(sql: "DELETE FROM episode WHERE accountId = ? AND seriesId = ? AND streamId NOT IN (SELECT value FROM json_each(?))",
                                  arguments: [aid, seriesId, ids])
                }
                for e in eps {
                    try d.execute(sql: """
                        INSERT INTO episode (accountId,seriesId,season,number,title,streamId,containerExt) VALUES (?,?,?,?,?,?,?)
                        ON CONFLICT(accountId,streamId) DO UPDATE SET seriesId=excluded.seriesId, season=excluded.season,
                          number=excluded.number, title=excluded.title, containerExt=excluded.containerExt
                        """, arguments: [e.accountId, e.seriesId, e.season, e.number, e.title, e.streamId, e.containerExt])
                }
            }
            return try cached()
        } catch {
            let c = try cached()
            if c.isEmpty { throw error }
            return c
        }
    }

    // MARK: Details

    /// What the provider says about a movie or series (Xtream only; M3U has nothing): from the cache for 14 days, else fetched.
    /// A failed fetch falls back to an older cached copy. An answer without details is not cached, so reopening tries again.
    public func info(account: Account, password: String?, type: ItemType, streamId: String,
                     now: Date = Date(), refresh: Bool = false) async throws -> ItemInfo {
        guard let aid = account.id, account.kind == .xtream, type != .live else { return ItemInfo() }
        func cached(_ maxAge: TimeInterval?) async throws -> ItemInfo? {
            try await db.dbQueue.read { try ItemInfoStore.cached($0, accountId: aid, type: type, streamId: streamId, now: now, maxAge: maxAge) }
        }
        if !refresh, let hit = try await cached(ItemInfoStore.ttl) { return hit }
        guard let urls = XtreamURLs(server: account.server ?? "", username: account.username ?? "", password: password ?? "")
        else { throw IPTVError.badConfig }
        do {
            let client = XtreamClient(urls: urls, session: session)
            let info = type == .movie ? try await client.vodInfo(streamId: streamId) : try await client.seriesInfo(seriesId: streamId)
            if info.hasContent { try await db.dbQueue.write { try ItemInfoStore.save($0, accountId: aid, type: type, streamId: streamId, info: info, now: now) } }
            return info
        } catch {
            if let stale = try? await cached(nil) { return stale }
            throw error
        }
    }
}
