import Foundation
import GRDB

public final class SyncService {
    let db: AppDatabase
    let session: URLSession
    public init(db: AppDatabase, session: URLSession = .shared) { self.db = db; self.session = session }

    public func sync(account: Account, password: String?) async throws {
        guard let aid = account.id else { throw IPTVError.badConfig }
        let (cats, items): ([Category], [Item])
        switch account.kind {
        case .xtream: (cats, items) = try await fetchXtream(account, aid, password ?? "")
        case .m3u: (cats, items) = try await fetchM3U(account, aid)
        }
        try await db.dbQueue.write { d in
            try d.execute(sql: "UPDATE item SET stale = 1 WHERE accountId = ?", arguments: [aid])
            try d.execute(sql: "DELETE FROM category WHERE accountId = ?", arguments: [aid])
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

    // MARK: Xtream

    private func fetchXtream(_ account: Account, _ aid: Int64, _ password: String) async throws -> ([Category], [Item]) {
        guard let urls = XtreamURLs(server: account.server ?? "", username: account.username ?? "", password: password)
        else { throw IPTVError.badConfig }
        let client = XtreamClient(urls: urls, session: session)
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
        let text = String(decoding: data, as: UTF8.self)
        let first = text.drop { $0.isWhitespace || $0 == "\u{FEFF}" }
        guard first.hasPrefix("#EXTM3U") else { throw IPTVError.badResponse }

        var parser = M3UParser()
        var items: [Item] = [], seenCats = Set<String>(), cats: [Category] = []
        for line in text.split(whereSeparator: \.isNewline) {
            guard let e = parser.feed(String(line)) else { continue }
            let type = M3UClassifier.type(url: e.url, group: e.group)
            if let g = e.group, seenCats.insert("\(type.rawValue)|\(g)").inserted {
                cats.append(Category(accountId: aid, type: type, remoteId: g, name: g))
            }
            items.append(Item(accountId: aid, type: type, name: e.name, streamId: e.url, categoryId: e.group,
                              icon: e.logo, directURL: e.url, tvArchive: e.catchupDays != nil,
                              archiveDays: e.catchupDays ?? 0, epgChannelId: e.tvgId))
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
            let info = try await XtreamClient(urls: urls, session: session).seriesInfo(seriesId)
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
            try await db.dbQueue.write { d in
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
}
