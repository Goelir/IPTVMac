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

`account(id, name, kind xtream|m3u, server, username, url)`. Passwords are stored in the app's own database file (`secret` table, plain text, owner-only permissions 0600 in a 0700 folder), not in the Keychain: the Keychain asks the user for access again on every new ad-hoc-signed build. Trade-off: the password is not encrypted at rest.

- **Xtream**: name, server URL (`http://host:port`), username, password.
- **M3U**: name and URL only. Local file import can be added later.

## Data model (SQLite)

- `category(id, account_id, type live|movie|series, name)`
- `item(id, account_id, type, name, category_id, icon, rating, added, stream_id, container_ext, tv_archive, archive_days, epg_channel_id)`
- `item_fts`: FTS5 on `name`, tokenizer `unicode61 remove_diacritics`, prefix search for type-as-you-go. Works for Hebrew, Arabic, Latin.
- `episode`: loaded lazily when a series is opened (`get_series_info`).
- `history(accountId, type, streamId, position, duration, updated)` and `favorite(accountId, type, streamId)`. Columns are camelCase to match the Swift records. "Continue watching" lists movies only (live channels are not recorded); episode resume works inside the series screen. M3U accounts have no catch-up (timeshift URLs are Xtream-only).

## Sync

**Xtream**: on login, in parallel: `get_live_categories`, `get_vod_categories`, `get_series_categories`, then `get_live_streams`, `get_vod_streams`, `get_series`. Written in batches inside a single transaction, off the main thread. Next launch shows the cached DB immediately and syncs in the background; items removed server-side are marked and dropped. EPG is fetched per channel on demand (`get_short_epg`), not as bulk XMLTV.

**M3U**: downloaded in full, then parsed line by line (ceiling: playlists above ~100 MB). `group-title` becomes the category, `tvg-logo` the icon. Item type is a heuristic: URL path `/movie/` or `/series/`, then group name, otherwise live. Known ceiling: misclassification; there is no per-category override in v1. Catch-up and EPG work only if the file carries `catchup` and `url-tvg`; otherwise those controls are hidden. Series episodes show as a flat list (no `get_series_info`).

## Search

One parameterized query. `scope`: category, type, or all. `type`: live, movie, series. Global search groups results into the three types. Input is debounced (~100 ms).

## Player

- `PlayerController` is the only code touching libmpv. API: `play(url)`, `pause`, `seek`, `setSubtitle(track)`, `setAudio(track)`.
- Rendered in an `NSViewRepresentable` (Metal/OpenGL).
- Stability: live-stream cache and `demuxer-readahead`, `stream-lavf-o=reconnect=1,reconnect_streamed=1`, automatic retry after failure, `hwdec=videotoolbox`.
- Stream URLs: live `/live/user/pass/id.ts` (or `.m3u8`), `/movie/...`, `/series/...`.
- Keys: space, arrows, F fullscreen, Esc, quick channel switching. Picture-in-Picture is a floating always-on-top mini window (all Spaces, over full-screen apps) hosting the same video view, with pause, return and close controls. It is not system `AVPictureInPictureController`, which needs `AVSampleBufferDisplayLayer` frames that libmpv's OpenGL renderer does not produce. The player is owned by the app model, so playback continues while the main window browses.

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

All strings through classic `Localizable.strings` files per `.lproj` (a String Catalog needs Xcode's `xcstringstool`, which is not installed). Initial languages: Hebrew, English, Arabic. More languages added as translation files via contributions. RTL layout follows SwiftUI automatically, with manual checks of the player and subtitles. UI language is independent of preferred subtitle/audio language.

## Errors

- Network failure: show cached data marked "not updated".
- Bad credentials: clear message in the guide and in settings.
- Stream failure: automatic retry, then an inline error in the player with a retry button.

## Testing

- Swift Testing unit tests (XCTest is not available with Command Line Tools only): M3U parser, Xtream and catch-up URL builders, search queries against a temporary DB.
- A mock Xtream server script for sync tests.
- Manual verification of the player against a real stream, since that cannot be automated.

## Distribution

A self-contained `IPTVMac.dmg` (Apple Silicon, arm64): libmpv and all of its dylibs are bundled into the app with `dylibbundler`, so end users install nothing else. Homebrew's mpv is needed only on the build machine. The DMG is attached to a GitHub Release, not committed to git history (it exceeds GitHub's 100 MB file limit). It is ad-hoc signed and not notarized (no Apple Developer ID), so other Macs show a Gatekeeper warning on first open (right-click, Open).

## Build notes

With Command Line Tools only, build and test through `scripts/swift.sh`: the macOS 27 SDK declares SwiftUI's `@State` and friends as macros whose plugin ships only with Xcode, so the wrapper selects the macOS 26.5 SDK.

## Updates

In-app updates without Sparkle. `UpdateChecker` reads the latest GitHub release (published, version tag, `IPTVMac.dmg` asset, and a `SHA-256 of IPTVMac.dmg: `<hash>`` line in the notes; anything else is ignored), compares versions numerically, downloads the DMG over HTTPS and verifies the hash. `UpdateInstaller` mounts it, copies the app, checks its version and code signature, and a detached shell script swaps the bundle after the app exits (old app kept on any failure), clears quarantine, and optionally relaunches. The staged update is applied on "Restart to update" or on the next quit. Checking at launch and every 6 h, and automatic download, are on by default and switchable in Settings. Not applied for `swift run` builds. Trade-off: the checksum comes from the same GitHub release, so it detects corruption, not a compromised GitHub account; real protection would need a signing key (Sparkle/EdDSA) or Apple notarization.
