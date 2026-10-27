import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:http/http.dart' as http;
import 'package:iptvmac/app/epg_cache.dart';
import 'package:iptvmac/app/prefs.dart';
import 'package:iptvmac/app/sync_worker.dart';
import 'package:iptvmac/app/watch_progress.dart';
import 'package:iptvmac/app/device.dart';
import 'package:iptvmac/core/android_update.dart';
import 'package:iptvmac/core/app_database.dart';
import 'package:iptvmac/core/backup.dart';
import 'package:iptvmac/core/category_filter.dart';
import 'package:iptvmac/core/errors.dart';
import 'package:iptvmac/core/item_info.dart';
import 'package:iptvmac/core/models.dart';
import 'package:iptvmac/core/refresh_schedule.dart';
import 'package:iptvmac/core/search.dart';
import 'package:iptvmac/core/secret_store.dart';
import 'package:iptvmac/core/subscription_info.dart';
import 'package:iptvmac/core/sync_service.dart';
import 'package:iptvmac/core/user_data.dart';
import 'package:iptvmac/core/xtream_client.dart';
import 'package:iptvmac/core/xtream_urls.dart';
import 'package:iptvmac/player/play_request.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SearchScope { category, type, everywhere }

enum ClearKind { history, favorites, images }

/// The app state (port of IPTVAppKit/LibraryModel.swift): playlists, the section being browsed, categories, search, favorites,
/// resume points, sync, EPG, preferences, backup. No widgets in here. Reads run on the UI isolate (30 ms for 5000 rows); the sync
/// runs through [SyncRunner] (a background isolate in the app).
class LibraryModel extends ChangeNotifier {
  LibraryModel({
    required this.db,
    required this.secrets,
    required SharedPreferences prefs,
    required String dbPath,
    SyncRunner? syncRunner,
    http.Client? client,
    this.dbMovedAside,
    this.searchDebounce = const Duration(milliseconds: 100),
    this.autoRefresh = true,
    this.appVersion,
    this.onClearImages,
    DateTime Function()? clock,
  })  : prefs = AppPrefs(prefs),
        _runner = syncRunner ?? isolateSyncRunner(dbPath),
        _client = client ?? http.Client(),
        _clock = clock ?? DateTime.now,
        _epg = EpgCache(clock: clock);

  final AppDatabase db;
  final SecretStore secrets;
  final AppPrefs prefs;

  /// Set when the database file was corrupt and moved aside at launch (the shell tells the user).
  final String? dbMovedAside;
  final Duration searchDebounce;
  final bool autoRefresh;

  /// The installed version ("1.0.2"); null where there is no update check (tests, debug launchers).
  final String? appVersion;
  final Future<void> Function()? onClearImages;
  final SyncRunner _runner;
  final http.Client _client;
  final DateTime Function() _clock;
  final EpgCache _epg;

  // ---- state the screens read ----
  List<Account> accounts = [];
  Account? account;

  /// All playlists at once (results, search, favorites and categories span every account).
  bool allPlaylists = false;
  ItemType tab = ItemType.live;
  List<Category> categories = [];

  /// Items per category, by [categoryTag] (for the category screen).
  Map<String, int> categoryCounts = {};

  /// The section opens on the category screen; picking a category (or its All row) leads into the list, the filter button back.
  bool showCategoryIndex = true;

  /// "__all", "__fav", "__hist", or a category tag (see [categoryTag]).
  String selectedCategory = '__all';
  String searchText = '';
  SearchScope scope = SearchScope.category;
  List<Item> results = [];
  bool syncing = false;

  /// How far the running sync is, 0..1 (every playlist counted in All mode); null when none is running.
  double? syncProgress;
  String? syncMessage;

  /// Set when an Xtream account has no stored password: the shell asks for it.
  Account? passwordPrompt;
  Set<String> favoriteKeys = {};
  Map<ItemType, List<Item>> favoriteItems = {};
  List<ContinueEntry> continueMovies = [], continueSeries = [];

  /// The last item played (the list highlights it).
  int? lastPlayedId;
  DateTime? lastSync;

  /// What each Xtream panel said about its subscription (the expiry date), by playlist id: the last answers are kept in the preferences,
  /// the settings screen refreshes them (one login request per playlist).
  late Map<int, SubscriptionInfo> subscriptions = prefs.subscriptions;

  final _passwords = <int, String>{}; // loaded from [secrets] at start: the player host needs stream URLs synchronously
  final _episodeByUrl = <String, Episode>{};
  Timer? _searchTimer, _refreshTimer;
  var _syncGen = 0, _started = false, _disposed = false;

  Account? get playlist => allPlaylists ? null : account;
  int? get _scopeAccountId => allPlaylists ? null : account?.id;
  bool get _hasPlaylist => allPlaylists || account != null;
  CategoryFilter get categoryFilter => CategoryFilter(prefs.hiddenWords);
  int get refreshHours => prefs.refreshHours;
  List<ContinueEntry> continueEntries(ItemType t) => t == ItemType.movie ? continueMovies : t == ItemType.series ? continueSeries : const [];

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ---- launch ----

  /// Loads the accounts (call before the first frame so a returning user never sees the welcome screen).
  Future<void> loadAccounts() async {
    accounts = db.read(Account.all);
    for (final a in accounts) {
      final id = a.id;
      if (a.kind == AccountKind.xtream && id != null && !_passwords.containsKey(id)) {
        final p = await secrets.password(id);
        if (p != null) _passwords[id] = p;
      }
    }
    if (account == null) {
      final r = Account.restore(prefs.playlist, accounts);
      allPlaylists = r.all;
      account = r.account;
      _playlistChanged(reset: false);
    } else if (!accounts.any((a) => a.id == account!.id)) {
      account = accounts.firstOrNull;
      _playlistChanged();
    } else {
      account = accounts.firstWhere((a) => a.id == account!.id); // a fresh copy (an edit changed the address)
    }
    if (accounts.length < 2 && allPlaylists) {
      allPlaylists = false;
      _playlistChanged();
    }
    notifyListeners();
  }

  // ---- app updates (GitHub releases feed; the install itself stays manual) ----

  UpdateCheck updateCheck = UpdateCheck.idle;

  /// A version newer than the installed one that the user has not dismissed (the banner); null otherwise.
  String? get updateAvailable {
    final v = prefs.latestAndroid, cur = appVersion;
    return v == null || cur == null || !isNewerVersion(v, cur) || prefs.dismissedAndroid == v ? null : v;
  }

  /// A newer version exists, dismissed or not (the settings row).
  String? get newerVersion {
    final v = prefs.latestAndroid, cur = appVersion;
    return v == null || cur == null || !isNewerVersion(v, cur) ? null : v;
  }

  /// Asks the releases feed. Automatic checks (at most one every 6 hours) respect the setting; [manual] checks always run and report.
  Future<void> checkForUpdate({bool manual = false}) async {
    if (appVersion == null || updateCheck == UpdateCheck.checking) return;
    if (!manual && (!prefs.autoCheckUpdates || _clock().millisecondsSinceEpoch - prefs.updateCheckedAt < 6 * 3600 * 1000)) return;
    updateCheck = UpdateCheck.checking;
    if (manual) notifyListeners();
    try {
      final v = await fetchNewestAndroidVersion(_client, channel: releaseChannel);
      prefs.updateCheckedAt = _clock().millisecondsSinceEpoch;
      if (v != null) prefs.latestAndroid = v;
      updateCheck = UpdateCheck.done;
    } catch (_) {
      updateCheck = UpdateCheck.failed; // offline, GitHub down: the next automatic check tries again
    }
    notifyListeners();
  }

  void dismissUpdate() {
    prefs.dismissedAndroid = prefs.latestAndroid;
    notifyListeners();
  }

  void setAutoCheckUpdates(bool v) {
    prefs.autoCheckUpdates = v;
    notifyListeners();
  }

  /// Loads the shown playlist's data once, starts the auto-refresh and syncs the shown playlist.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    unawaited(checkForUpdate());
    if (autoRefresh) _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) => _refreshTick());
    if (accounts.isEmpty) await loadAccounts();
    if (account != null) await sync();
  }

  void _refreshTick() {
    if (!syncing && accounts.isNotEmpty && RefreshSchedule.isDue(hours: refreshHours, lastSync: lastSync, now: _clock())) sync();
  }

  // ---- playlists ----

  /// The toolbar switcher: null = all playlists.
  void selectPlaylist(Account? a) {
    if (a == null) {
      if (allPlaylists || accounts.length < 2) return;
      allPlaylists = true;
    } else {
      if (!allPlaylists && account?.id == a.id) return;
      account = a;
      allPlaylists = false;
    }
    _playlistChanged();
    notifyListeners();
  }

  void _playlistChanged({bool reset = true}) {
    prefs.playlist = allPlaylists ? 'all' : account?.id?.toString();
    if (reset) {
      selectedCategory = '__all';
      searchText = '';
    }
    favoriteKeys = {};
    loadCategories();
    loadFavorites();
    reloadContinue();
    scheduleSearch(immediate: true);
  }

  void setTab(ItemType t) {
    if (t == tab) return;
    tab = t;
    selectedCategory = '__all';
    showCategoryIndex = true;
    searchText = '';
    loadCategories();
    scheduleSearch(immediate: true);
    notifyListeners();
  }

  void loadCategories() {
    if (!_hasPlaylist) {
      categories = [];
      return;
    }
    final aid = _scopeAccountId;
    final rows = db.read((d) => d.select(
        'SELECT * FROM category WHERE type = ? AND (? IS NULL OR accountId = ?) ORDER BY accountId, id', [tab.name, aid, aid]));
    categories = categoryFilter.visibleCategories([for (final r in rows) Category.fromRow(r)]);
    final counts = db.read((d) => d.select(
        'SELECT accountId, categoryId, COUNT(*) AS n FROM item WHERE type = ? AND (? IS NULL OR accountId = ?) GROUP BY accountId, categoryId',
        [tab.name, aid, aid]));
    categoryCounts = {for (final r in counts) if (r['categoryId'] != null) allPlaylists ? '${r['accountId']}|${r['categoryId']}' : '${r['categoryId']}': r['n'] as int};
  }

  void openCategoryIndex() {
    showCategoryIndex = true;
    notifyListeners();
  }

  /// In All mode a category is tagged `accountId|remoteId` (remote ids repeat across playlists); otherwise by remote id.
  String categoryTag(Category c) => allPlaylists ? '${c.accountId}|${c.remoteId}' : c.remoteId;

  void selectCategory(String tag) {
    selectedCategory = tag;
    showCategoryIndex = false;
    scheduleSearch(immediate: true);
    notifyListeners();
  }

  // ---- search ----

  void setSearchText(String t) {
    if (t == searchText) return;
    searchText = t;
    scheduleSearch();
    notifyListeners();
  }

  void setScope(SearchScope s) {
    scope = s;
    scheduleSearch(immediate: true);
    notifyListeners();
  }

  void scheduleSearch({bool immediate = false}) {
    _searchTimer?.cancel();
    if (!_hasPlaylist) {
      results = [];
      notifyListeners();
      return;
    }
    if (immediate || searchText.isEmpty) {
      _runSearch();
    } else {
      _searchTimer = Timer(searchDebounce, _runSearch);
    }
  }

  void _runSearch() {
    final text = searchText, cat = selectedCategory, aid = _scopeAccountId, hide = categoryFilter;
    results = db.read((d) {
      final List<Item> found;
      if (text.isEmpty && cat == '__fav') {
        found = UserData.favorites(d, accountId: aid, type: tab);
      } else if (text.isEmpty && cat == '__hist') {
        found = UserData.continueWatching(d, accountId: aid, type: tab);
      } else {
        var owner = aid;
        String? catId;
        if (scope == SearchScope.category && !cat.startsWith('__')) {
          if (!allPlaylists) {
            catId = cat;
          } else {
            final bar = cat.indexOf('|');
            if (bar > 0) {
              owner = int.tryParse(cat.substring(0, bar));
              catId = cat.substring(bar + 1);
            }
          }
        }
        final type = scope == SearchScope.everywhere && text.isNotEmpty ? null : tab;
        found = Search.run(d, SearchRequest(accountId: owner, text: text, type: type, categoryId: catId));
      }
      return hide.visible(found, d);
    });
    notifyListeners();
  }

  // ---- favorites, continue watching ----

  bool isFavorite(Item i) => favoriteKeys.contains(UserData.favoriteKey(accountId: i.accountId, type: i.type, streamId: i.streamId));

  void loadFavorites() {
    if (!_hasPlaylist) return;
    final aid = _scopeAccountId, hide = categoryFilter;
    db.read((d) {
      favoriteKeys = UserData.favoriteKeys(d, accountId: aid);
      favoriteItems = {for (final t in ItemType.values) t: hide.visible(UserData.favorites(d, accountId: aid, type: t), d)};
    });
  }

  Future<void> toggleFavorite(Item i) async {
    try {
      db.write((d) => UserData.toggleFavorite(d, accountId: i.accountId, type: i.type, streamId: i.streamId));
    } catch (e) {
      syncMessage = describeError(e);
    }
    loadFavorites();
    if (selectedCategory == '__fav') scheduleSearch(immediate: true);
    notifyListeners();
  }

  void reloadContinue() {
    if (!_hasPlaylist) {
      continueMovies = [];
      continueSeries = [];
      return;
    }
    final aid = _scopeAccountId, hide = categoryFilter;
    db.read((d) {
      List<ContinueEntry> visible(ItemType t) {
        final all = WatchProgress.continueEntries(d, accountId: aid, type: t);
        final ok = {for (final i in hide.visible([for (final e in all) e.item], d)) i.id};
        return [for (final e in all) if (ok.contains(e.item.id)) e];
      }

      continueMovies = visible(ItemType.movie);
      continueSeries = visible(ItemType.series);
    });
    notifyListeners();
  }

  double progress(Item i) => db.read((d) => UserData.progress(d, accountId: i.accountId, type: i.type, streamId: i.streamId)) ?? 0;

  void hiddenCategoriesChanged() {
    loadCategories();
    if (!selectedCategory.startsWith('__') && !categories.any((c) => categoryTag(c) == selectedCategory)) selectedCategory = '__all';
    loadFavorites();
    reloadContinue();
    scheduleSearch(immediate: true);
    notifyListeners();
  }

  // ---- sync ----

  bool hasPassword(Account a) => a.kind != AccountKind.xtream || a.id == null || _passwords.containsKey(a.id); // "" = deliberately none

  /// Syncs the shown playlist, or every playlist one after the other in All mode.
  Future<void> sync([List<Account>? targets]) async {
    targets ??= allPlaylists ? accounts : [?account];
    lastSync = _clock(); // an attempt counts: a failing provider is not retried every minute
    final missing = targets.where((a) => !hasPassword(a)).firstOrNull;
    if (missing != null) {
      passwordPrompt = missing;
      notifyListeners();
    }
    final ready = targets.where(hasPassword).toList();
    if (ready.isEmpty) return;
    final gen = ++_syncGen;
    syncing = true;
    syncMessage = null;
    syncProgress = 0;
    notifyListeners();
    final failures = <String>[];
    for (final (index, a) in ready.indexed) {
      final share = 1 / ready.length, base = index * share; // All mode: the playlists go one after the other
      String? error;
      try {
        error = await _runner(a, _passwords[a.id] ?? '', (p) {
          final v = base + p * share;
          if (gen != _syncGen || v <= (syncProgress ?? 0)) return;
          syncProgress = v;
          notifyListeners();
        });
      } catch (e) {
        error = describeError(e);
      }
      if (gen != _syncGen) return; // a newer sync owns the UI state now
      if (error != null) failures.add(ready.length > 1 ? '${a.name}: $error' : error);
    }
    syncing = false;
    syncProgress = null;
    syncMessage = failures.isEmpty ? null : failures.join('; ');
    loadCategories();
    loadFavorites();
    reloadContinue();
    scheduleSearch(immediate: true);
    notifyListeners();
  }

  Future<void> savePassword(String password, Account a) async {
    final id = a.id;
    if (id == null) return;
    try {
      await secrets.setPassword(id, password);
    } catch (e) {
      syncMessage = describeError(e);
      notifyListeners();
      return;
    }
    _passwords[id] = password;
    passwordPrompt = null;
    notifyListeners();
    await sync([a]); // saving a password must not switch the selected playlist
  }

  void dismissPasswordPrompt() {
    passwordPrompt = null;
    notifyListeners();
  }

  /// Saves a new source and starts its first sync (not awaited: the form closes at once and the status strip shows the progress).
  /// False when it could not be saved ([syncMessage] says why).
  Future<bool> addAccount(Account a, {String? password}) async {
    try {
      db.write((d) => a.insert(d));
      final id = a.id;
      if (password != null && id != null) {
        await secrets.setPassword(id, password);
        _passwords[id] = password;
      }
    } catch (e) {
      syncMessage = describeError(e);
      notifyListeners();
      return false;
    }
    await loadAccounts();
    final added = accounts.where((x) => x.id == a.id).firstOrNull;
    if (added != null && !allPlaylists && account?.id != added.id) {
      account = added;
      _playlistChanged();
    }
    unawaited(sync([?added]));
    return true;
  }

  /// Saves edits to a source (name, address, login; a new password only when given) and syncs it again.
  Future<void> updateAccount(Account a, {String? password}) async {
    final id = a.id;
    if (id == null) return;
    try {
      db.write((d) => d.execute('UPDATE account SET name=?, server=?, username=?, url=? WHERE id=?', [a.name, a.server, a.username, a.url, id]));
      if (password != null && password.isNotEmpty) {
        await secrets.setPassword(id, password);
        _passwords[id] = password;
      }
    } catch (e) {
      syncMessage = describeError(e);
      notifyListeners();
      return;
    }
    await loadAccounts();
    await sync([?accounts.where((x) => x.id == id).firstOrNull]);
  }

  Future<void> deleteAccount(Account a) async {
    final id = a.id;
    if (id == null) return;
    db.write((d) {
      d.execute('DELETE FROM favorite WHERE accountId = ?', [id]); // M3U ids are full URLs with credentials
      d.execute('DELETE FROM history WHERE accountId = ?', [id]);
      d.execute('DELETE FROM account WHERE id = ?', [id]);
    });
    await secrets.deletePassword(id);
    _passwords.remove(id);
    if (subscriptions.containsKey(id)) {
      subscriptions = {...subscriptions}..remove(id);
      prefs.subscriptions = subscriptions;
    }
    await loadAccounts();
    if (allPlaylists && selectedCategory.startsWith('$id|')) selectedCategory = '__all';
    loadCategories();
    loadFavorites();
    reloadContinue();
    scheduleSearch(immediate: true);
    notifyListeners();
  }

  Account? accountById(int id) => accounts.where((a) => a.id == id).firstOrNull;

  // ---- playback requests ----

  /// URLs for an Xtream account: the one that owns the item/series, else the current account.
  XtreamURLs? xtreamUrls([int? accountId]) {
    final a = (accountId == null ? null : accountById(accountId)) ?? account;
    if (a == null || a.kind != AccountKind.xtream || a.id == null) return null;
    return XtreamURLs.parse(server: a.server ?? '', username: a.username ?? '', password: _passwords[a.id] ?? '');
  }

  Uri? streamUrl(Item i) {
    final d = i.directURL;
    if (d != null) return safeStreamUrl(d);
    return xtreamUrls(i.accountId)?.stream(i.type, i.streamId, i.containerExt);
  }

  /// An M3U entry is untrusted: mpv would also open fd://, file://, edl://, memory:// ... so only network schemes pass.
  static Uri? safeStreamUrl(String s) {
    final u = Uri.tryParse(s.trim());
    if (u == null || u.host.isEmpty) return null;
    return const ['http', 'https', 'rtmp', 'rtmps', 'rtsp', 'udp', 'rtp', 'mms', 'mmsh'].contains(u.scheme.toLowerCase()) ? u : null;
  }

  /// A series (not a direct URL) opens its episode list instead of playing.
  bool opensSeries(Item i) => i.type == ItemType.series && i.directURL == null;

  /// The request for a movie, channel or direct-URL entry; null (with [passwordPrompt] or [syncMessage] set) when it cannot play.
  PlayRequest? requestFor(Item item) {
    final a = accountById(item.accountId);
    if (a != null && !hasPassword(a)) {
      passwordPrompt = a;
      notifyListeners();
      return null;
    }
    final url = streamUrl(item);
    if (url == null) {
      syncMessage = IPTVError.badConfig.description;
      notifyListeners();
      return null;
    }
    lastPlayedId = item.id;
    final live = item.type == ItemType.live;
    return PlayRequest(
        title: item.name, url: url, isLive: live, item: item, start: live ? 0 : progress(item), subtitle: live ? _epg.now(item)?.title : null);
  }

  /// The request for an episode; remembers which episode the URL is (progress is saved as `ep:` plus the episode id).
  PlayRequest? episodeRequest(Episode e, Item series) {
    final url = xtreamUrls(series.accountId)?.series(e.streamId, e.containerExt);
    if (url == null) return null;
    _episodeByUrl[url.toString()] = e;
    lastPlayedId = series.id;
    final p = db.read((d) => UserData.progress(d, accountId: series.accountId, type: ItemType.series, streamId: 'ep:${e.streamId}'));
    return PlayRequest(title: series.name, url: url, isLive: false, item: series, start: p ?? 0, subtitle: e.title);
  }

  Episode? episodeOf(PlayRequest r) => _episodeByUrl[r.url.toString()];

  /// A downloaded file plays under the same progress key as the stream: remember which episode its (file) URL is.
  void rememberEpisode(Uri url, Episode e) => _episodeByUrl[url.toString()] = e;

  /// Starting a download of an Xtream source whose password is missing asks for it, like playing does. True when it is known.
  bool ensurePassword(int accountId) {
    final a = accountById(accountId);
    if (a == null || hasPassword(a)) return true;
    passwordPrompt = a;
    notifyListeners();
    return false;
  }

  List<Episode> cachedEpisodes(Item series) => db.read((d) => [
        for (final r in d.select('SELECT * FROM episode WHERE accountId = ? AND seriesId = ? ORDER BY season, number', [series.accountId, series.streamId]))
          Episode.fromRow(r)
      ]);

  /// Periodic saves while playing and the final one when the player closes. Never for live. Does not redraw (every 20 s).
  void saveProgress(PlayRequest r, double position, double duration) {
    final item = r.item;
    if (r.isLive || item == null) return;
    final e = episodeOf(r);
    try {
      db.write((d) => UserData.saveProgress(d,
          accountId: item.accountId, type: item.type, streamId: e == null ? item.streamId : 'ep:${e.streamId}', position: position, duration: duration));
    } catch (_) {
      // the database is busy or full: the next periodic save tries again
    }
  }

  // ---- EPG ----

  String? epgTitle(Item i) => _epg.now(i)?.title;
  ({EPGEntry? now, EPGEntry? next}) epgPrograms(Item i) => _epg.programs(i);

  Future<void> loadEpgNow(Item i) async {
    if (await _epg.load(i, xtreamUrls(i.accountId), (u) => XtreamClient(u, client: _client))) notifyListeners();
  }

  // ---- details and episodes ----

  /// Details exist only for movies and series of an Xtream playlist (an M3U file has none).
  bool hasInfo(Item i) => i.type != ItemType.live && accountById(i.accountId)?.kind == AccountKind.xtream;

  Future<ItemInfo> loadInfo(Item i, {bool refresh = false}) async {
    final a = accountById(i.accountId);
    if (a == null) return ItemInfo();
    if (!hasPassword(a)) throw IPTVError.badCredentials;
    return SyncService(db, client: _client).info(a, password: _passwords[a.id], type: i.type, streamId: i.streamId, refresh: refresh);
  }

  /// Whatever is cached, however old: shown at once while a fresh copy is on its way.
  ItemInfo? cachedInfo(Item i) => db.read((d) => ItemInfoStore.cached(d, accountId: i.accountId, type: i.type, streamId: i.streamId, maxAge: null));

  Future<List<Episode>> loadEpisodes(Item series) async {
    final a = accountById(series.accountId);
    if (a == null) throw IPTVError.badConfig;
    return SyncService(db, client: _client).episodes(a, password: _passwords[a.id], seriesId: series.streamId);
  }

  Map<String, EpisodeProgress> episodeProgress(Item series) => db.read((d) => WatchProgress.episodeProgress(d, accountId: series.accountId));

  // ---- preferences, backup, clearing ----

  void setRefreshHours(int h) {
    prefs.refreshHours = h;
    notifyListeners();
  }

  void setAppearance(String v) {
    prefs.appearance = v;
    notifyListeners();
  }

  void setHiddenWords(String v) {
    prefs.hiddenWords = v;
    hiddenCategoriesChanged();
  }

  String backupJson() => db.read((d) => Backup.make(d).encoded());

  /// Merges a backup file. New playlists are synced; an Xtream one has no password yet, so sync() asks for it.
  /// Throws [BackupError].
  Future<void> importBackup(Uint8List bytes) async {
    final backup = Backup.decode(bytes);
    final added = db.write(backup.merge);
    await loadAccounts();
    loadFavorites();
    reloadContinue();
    scheduleSearch(immediate: true);
    final ids = {for (final a in added) a.id};
    await sync([for (final a in accounts) if (ids.contains(a.id)) a]);
  }

  Future<void> clear(ClearKind kind) async {
    switch (kind) {
      case ClearKind.history:
        db.write(UserData.clearHistory);
      case ClearKind.favorites:
        db.write(UserData.clearFavorites);
      case ClearKind.images:
        await onClearImages?.call();
    }
    loadFavorites();
    reloadContinue();
    scheduleSearch(immediate: true);
    notifyListeners();
  }

  /// Asks the panel again. A failed request (offline, wrong password, a panel without the field) keeps what was known.
  Future<void> refreshSubscription(Account a) async {
    final id = a.id;
    if (a.kind != AccountKind.xtream || id == null || !hasPassword(a)) return;
    final u = XtreamURLs.parse(server: a.server ?? '', username: a.username ?? '', password: _passwords[id] ?? '');
    if (u == null) return;
    try {
      final info = await XtreamClient(u, client: _client).subscription();
      if (subscriptions[id] == info) return;
      subscriptions = {...subscriptions, id: info};
      prefs.subscriptions = subscriptions;
      notifyListeners();
    } catch (_) {}
  }

  // ---- adding a source ----

  /// Checks a new source before it is saved: Xtream must log in, an M3U link must answer with a playlist. Throws.
  Future<void> testConnection({
    required AccountKind kind,
    String server = '',
    String username = '',
    String password = '',
    String url = '',
  }) async {
    final c = _client;
    if (kind == AccountKind.xtream) {
      final u = XtreamURLs.parse(server: server, username: username, password: password);
      if (u == null) throw IPTVError.badConfig;
      await XtreamClient(u, client: c).authenticate();
      return;
    }
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) throw IPTVError.badConfig;
    final resp = await c.send(http.Request('GET', uri)..headers['Range'] = 'bytes=0-1023').timeout(const Duration(seconds: 20));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      await resp.stream.listen(null).cancel();
      throw IPTVError.http(resp.statusCode);
    }
    final head = BytesBuilder();
    await for (final chunk in resp.stream.timeout(const Duration(seconds: 20))) {
      head.add(chunk);
      if (head.length >= 1024) break; // a server that ignores Range must not make us read the whole list
    }
    final text = utf8.decode(head.takeBytes(), allowMalformed: true).trimLeft().replaceFirst('\u{FEFF}', '').trimLeft();
    if (!text.startsWith('#EXTM3U')) throw IPTVError.badResponse;
  }
}

enum UpdateCheck { idle, checking, done, failed }
