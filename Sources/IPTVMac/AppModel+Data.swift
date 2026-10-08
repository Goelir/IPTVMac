import AppKit
import IPTVCore

enum ClearKind: String, CaseIterable, Identifiable { case history, favorites, images; var id: String { rawValue } }

/// Preferences that change what the lists show or when they update, plus backup and "clear data".
extension AppModel {
    var refreshHours: Int { UserDefaults.standard.integer(forKey: "refreshHours") }                     // 0 = only when the app opens
    var categoryFilter: CategoryFilter { CategoryFilter(UserDefaults.standard.string(forKey: "hiddenCategoryWords") ?? "") }

    /// Syncs what is shown (the playlist, or all of them) once `refreshHours` have passed since the last sync; ends when cancelled.
    func refreshLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled else { return }
            if !syncing, !accounts.isEmpty, RefreshSchedule.isDue(hours: refreshHours, lastSync: lastSync, now: Date()) { await sync() }
        }
    }

    /// The hidden words changed: the sidebar and the lists are filtered again (a selected category that is now hidden is left).
    func hiddenCategoriesChanged() {
        loadCategories()
        if !selectedCategory.hasPrefix("__"), !categories.contains(where: { categoryTag($0) == selectedCategory }) { selectedCategory = "__all" }
        scheduleSearch()
    }

    /// Details exist only for movies and series of an Xtream playlist (an M3U file has none).
    func hasInfo(_ item: Item) -> Bool { item.type != .live && playlist(id: item.accountId)?.kind == .xtream }

    /// The provider's details for a title: cached for 14 days, else fetched (never for a whole list, only when a sheet asks).
    func loadInfo(_ item: Item, refresh: Bool = false) async throws -> ItemInfo {
        guard let a = playlist(id: item.accountId), let id = a.id else { return ItemInfo() }
        guard hasPassword(a) else { throw IPTVError.badCredentials }
        return try await SyncService(db: db).info(account: a, password: secrets.password(for: id), type: item.type, streamId: item.streamId, refresh: refresh)
    }

    /// Whatever is cached, however old: for showing something at once while a fresh copy is on its way.
    func cachedInfo(_ item: Item) async -> ItemInfo? {
        try? await db.dbQueue.read { try ItemInfoStore.cached($0, accountId: item.accountId, type: item.type, streamId: item.streamId, maxAge: nil) }
    }

    /// Only the link we build from the validated video id is ever opened, never a URL from the provider.
    func openTrailer(_ info: ItemInfo) { if let u = info.trailerURL { NSWorkspace.shared.open(u) } }

    func exportBackup(to url: URL) async throws {
        try await db.dbQueue.read { try Backup.make($0) }.write(to: url)
    }

    /// Merges a backup file. New playlists are synced; an Xtream one has no password yet, so sync() asks for it.
    func importBackup(from url: URL) async throws {
        let backup = try Backup.read(from: url)
        let added = try await db.dbQueue.write { try backup.merge(into: $0) }.compactMap(\.id)
        loadAccounts(); loadFavorites(); scheduleSearch()
        await sync(accounts.filter { added.contains($0.id ?? 0) })
        if passwordPrompt != nil { showMainWindow() }           // the prompt is a sheet of the main window, not of Settings
    }

    func clear(_ kind: ClearKind) {
        switch kind {
        case .history: _ = try? db.dbQueue.write { try UserData.clearHistory($0) }
        case .favorites: _ = try? db.dbQueue.write { try UserData.clearFavorites($0) }
        case .images: URLCache.shared.removeAllCachedResponses()
        }
        loadFavorites(); scheduleSearch()
    }
}
