# Claims ledger for the website

Every number and every "better than" sentence on the site must have a row here, with its evidence and the date it was checked.
Pages are written from this file. Recheck the rows about other apps every 6 months.

| Claim | Wording on the site (EN / HE) | Evidence | Checked |
|---|---|---|---|
| Search stays fast with 100,000 items | "instant search over 100,000 items" / "חיפוש מיידי" | `Tests/IPTVCoreTests/SearchTests.swift:89-110` (100,000 rows, each search under 250 ms); `flutter/test/core/performance_test.dart:24` (same target on Android/Windows) | 2026-11-11 |
| 31 languages | "31 languages" / "31 שפות" | `Sources/IPTVMac/Resources/*.lproj` (31 folders; `scripts/check-strings.py` checks all of them) | 2026-11-11 |
| Free, no ads, no account, no analytics | "Completely free and open source, with no account" | LICENSE (GPL-3.0); no analytics or ad SDK in `Package.swift`, `ios/project.yml`, `flutter/pubspec.yaml` | 2026-11-11 |
| Mac app signed and notarized | "Signed with an Apple Developer ID and notarized by Apple" | `scripts/NOTARIZE.md`; releases from v0.9.1 on (`NOTARIZED_FROM` in `scripts/site/build.py`) | 2026-11-11 |
| iPhone and iPad app on the App Store, free | "on the App Store, completely free" | App Store id 6821761790 (`APP_STORE_ID` in `scripts/site/build.py`); version in `IOS_VERSION` | 2026-11-11 |
| Platforms | Mac, Windows, iPhone and iPad, Android, Android TV / Google TV / Fire TV; the App Store app is also available on Apple Silicon Macs | release tags `v*`, `windows-v*`, `android-v*`; App Store listing; 1.0.2 installed from the Mac App Store on 2026-11-13 (iTunesMetadata, not TestFlight); App Store Connect > Pricing and Availability > iPhone and iPad Apps on Apple Silicon Macs left on | 2026-11-13 |
| Reconnects when a live channel drops | "reconnects when a live channel drops" / "מתחבר מחדש כשערוץ חי נופל" | `Sources/IPTVPlayer/PlaybackWatch.swift` (`LiveRecovery`), `flutter/lib/player/playback_watch.dart` | 2026-11-11 |
| Hardware video decoding | "decodes video in hardware" / "מפענח וידאו בחומרה" | `Sources/IPTVPlayer/MPVPlayer.swift:31` (`hwdec=videotoolbox`); `flutter/lib/player/player_options.dart:33` (`mediacodec-copy,auto-safe`, `auto-safe`) | 2026-11-11 |
| Native code per platform, no Electron or web view | "Swift on Mac, iPhone and iPad. Flutter and Kotlin on Android, Android TV and Windows." | `Sources/`, `ios/` (Swift); `flutter/` (Dart, Kotlin in `flutter/android`, C++ runner in `flutter/windows`) | 2026-11-11 |
| Catch-up is Mac only; downloads on Mac, Windows and Android (not iPhone/iPad, not TV); continue watching, skip intro/credits and PiP everywhere except PiP on TV | the guide block "Everything a viewer needs", `/why/` | catch-up: `Sources/IPTVMac/CatchupView.swift` (no catch-up UI in `ios/Sources` or `flutter/lib`); downloads: `Sources/IPTVMac/Downloads.swift`, `flutter/lib/downloads/` (none in `ios/Sources`); skip marks: `Sources/IPTVCore/SkipMarks.swift`. Fixed on 2026-11-11: the iPhone section used to claim catch-up and downloads | 2026-11-11 |
| Search under a quarter of a second on 100,000 titles | "under a quarter of a second on a library of 100,000 titles, in our own tests" | same as the first row (the tests assert < 250 ms) | 2026-11-11 |

## Other apps (phase 4)

Read on 2026-11-11 (US store pages). The full tables are in `COMPARE` and the source lists in `SRC` in `scripts/site/pages.py`.

| App | Fact on the site | Source |
|---|---|---|
| IPTV Smarters Pro | App Store build "Smarters Player Lite": free, in-app purchase "Buy Premium Version $1.99", "Contains Advertising", privacy label "Data Used to Track You: Usage Data", Mac build "Designed for iPad", version 1.4.2 of 2026-09-11 | https://apps.apple.com/us/app/smarters-player-lite/id1628995509 |
| IPTV Smarters Pro | Recurring premium plan; premium includes PiP, external EPG, parental control; proprietary ("proprietary code") | https://getiptvsmarters.com/terms |
| IPTV Smarters Pro | Platforms: Android, Android TV, iOS/iPadOS/Apple TV, macOS, Windows, LG and Samsung TVs | https://getiptvsmarters.com/download |
| IPTV Smarters Pro | Catch-up, EPG, PiP, M3U, API login listed; downloads/recording not listed | https://getiptvsmarters.com/features |
| IPTV Smarters Pro | Google Play listing com.nst.iptvsmarterstvbox returned 404 | https://play.google.com/store/apps/details?id=com.nst.iptvsmarterstvbox |
| TiviMate | In-app purchases $0.99-$33.99 per item; no "Contains ads"; "not optimized for touch devices such as phones or tablets"; M3U, Xtream Codes, Stalker; EPG grid, catch-up, recording, multiview; updated 2026-06-22 | https://play.google.com/store/apps/details?id=ar.tvplayer.tv |
| TiviMate | Data safety: device IDs and app interactions for analytics, email for account management | https://play.google.com/store/apps/datasafety?id=ar.tvplayer.tv |
| TiviMate | Lifetime purchase and subscriptions; proprietary (no reverse engineering); Premium account by email | https://tivimate.com/terms-of-use |
| VLC | "Completely Free - no spyware, no ads and no user tracking"; platforms; version 3.0.24 of 2026-09-22 | https://www.videolan.org/vlc/ , https://www.videolan.org/news.html |
| VLC | Reads M3U/M3U8 playlists; no official Xtream Codes, XMLTV/EPG grid for M3U channels or catch-up found | https://wiki.videolan.org/Documentation:Modules/playlist |
| VLC | Picture in Picture popup on Android | https://play.google.com/store/apps/details?id=org.videolan.vlc |
