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
| Platforms | Mac, Windows, iPhone and iPad, Android, Android TV / Google TV / Fire TV | release tags `v*`, `windows-v*`, `android-v*`; App Store listing | 2026-11-11 |

## Other apps (phase 4)

Not filled in yet. One row per fact, with the source URL (store listing or the app's own site) and the date read.
