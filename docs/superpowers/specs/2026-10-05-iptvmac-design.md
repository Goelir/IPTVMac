# IPTVMac: Design

Date: 2026-10-05
Status: draft, pending user review

## Goal

A native, open-source macOS IPTV player for Xtream Codes and M3U sources. It should feel smooth like Televizo, with very fast search, a stable built-in player, subtitles, catch-up on supporting channels, and a multilingual UI. Personal use first; distributed as source on git. No App Store target for now.

## Decisions

| Area | Choice | Reason |
|---|---|---|
| Stack | Swift + SwiftUI, macOS only | Smoothest, lowest memory with large lists |
| Player | libmpv, wrapped in one `PlayerController` | Handles broken TS/HLS streams, strong subtitle support, GPL fits open source |
| Storage and search | SQLite via GRDB, FTS5 for search | Millisecond search over 100k+ items, persists between launches |
| License | GPL-compatible (libmpv) | Open source on git |

Rejected: AVPlayer (fails on many IPTV streams), VLCKit (heavier, less flexible), in-memory search (slow cold start, memory heavy), Tauri/Electron (heavier, less smooth).

## Scope

In: Live / Movies / Series sections, search (in category, in type, everywhere), built-in player, embedded and external subtitles, catch-up, favorites and resume, multiple accounts, first-run guide, UI localization (he, en, ar to start; RTL supported).

Out of v1: recording, multi-window, cross-device sync, iOS.

## Accounts

`account(id, name, kind xtream|m3u, server, username, url)`. Password is stored in Keychain, never in the database.

- **Xtream**: name, server URL (`http://host:port`), username, password.
- **M3U**: name and URL only. Local file import can be added later.

## Data model (SQLite)

- `category(id, account_id, type live|movie|series, name)`
- `item(id, account_id, type, name, category_id, icon, rating, added, stream_id, container_ext, tv_archive, archive_days, epg_channel_id)`
- `item_fts`: FTS5 on `name`, tokenizer `unicode61 remove_diacritics`, prefix search for type-as-you-go. Works for Hebrew, Arabic, Latin.
- `episode`: loaded lazily when a series is opened (`get_series_info`).
- `history(item_id, position, updated)` and `favorite(item_id)`.

## Sync

**Xtream**: on login, in parallel: `get_live_categories`, `get_vod_categories`, `get_series_categories`, then `get_live_streams`, `get_vod_streams`, `get_series`. Written in batches inside a single transaction, off the main thread. Next launch shows the cached DB immediately and syncs in the background; items removed server-side are marked and dropped. EPG is fetched per channel on demand (`get_short_epg`), not as bulk XMLTV.

**M3U**: stream-parsed (no full file in memory). `group-title` becomes the category, `tvg-logo` the icon. Item type is a heuristic: URL path `/movie/` or `/series/`, then group name, otherwise live. Known ceiling: misclassification; the user can override the type per category in settings. Catch-up and EPG work only if the file carries `catchup` and `url-tvg`; otherwise those controls are hidden. Series episodes show as a flat list (no `get_series_info`).

## Search

One parameterized query. `scope`: category, type, or all. `type`: live, movie, series. Global search groups results into the three types. Input is debounced (~100 ms).

## Player

- `PlayerController` is the only code touching libmpv. API: `play(url)`, `pause`, `seek`, `setSubtitle(track)`, `setAudio(track)`.
- Rendered in an `NSViewRepresentable` (Metal/OpenGL).
- Stability: live-stream cache and `demuxer-readahead`, `stream-lavf-o=reconnect=1,reconnect_streamed=1`, automatic retry after failure, `hwdec=videotoolbox`.
- Stream URLs: live `/live/user/pass/id.ts` (or `.m3u8`), `/movie/...`, `/series/...`.
- Keys: space, arrows, F fullscreen, Esc, quick channel switching. Picture-in-Picture supported.

### Subtitles

Embedded tracks are listed from mpv with per-language selection and an off option. External SRT/ASS via drag-and-drop or menu (`sub-add`). Settings: size, color, position, delay (`sub-delay`). RTL rendering checked for Hebrew. Preferred subtitle and audio languages are remembered.

### Catch-up

Shown only for channels with `tv_archive=1`. The user picks a day and time from the channel's EPG, up to `archive_days` back. URL: `/timeshift/user/pass/{duration}/{YYYY-MM-DD:HH-MM}/{id}.ts`. Unsupported channels show no button.

## UI

`NavigationSplitView`.

- Top bar: Live / Movies / Series tabs, a large search field with an "in category / in type / everywhere" toggle, and an account picker.
- Sidebar: categories of the active tab with item counts and a quick filter.
- Main area: channels as a list (logo and current program); movies and series as a poster grid. `LazyVStack`/`LazyVGrid` so 100k rows scroll smoothly.
- Favorites and continue-watching at the top of each tab.

### First-run guide

Shown only when no account exists; reopenable from Settings, Help. Three steps:

1. Welcome and what the app does.
2. Where to put the addresses: **Xtream** (name, server URL, username, password, with an example and where the provider shows them) or **M3U** (name and link).
3. Test connection (clear error on failure), then start sync with progress.

## Localization

All strings through a String Catalog (`.xcstrings`). Initial languages: Hebrew, English, Arabic. More languages added as translation files via contributions. RTL layout follows SwiftUI automatically, with manual checks of the player and subtitles. UI language is independent of preferred subtitle/audio language.

## Errors

- Network failure: show cached data marked "not updated".
- Bad credentials: clear message in the guide and in settings.
- Stream failure: automatic retry, then an inline error in the player with a retry button.

## Testing

- XCTest unit tests: M3U parser, Xtream and catch-up URL builders, search queries against a temporary DB.
- A mock Xtream server script for sync tests.
- Manual verification of the player against a real stream, since that cannot be automated.
