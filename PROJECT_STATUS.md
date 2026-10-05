# IPTVMac — Project Status

> Single source of truth for progress. Read this file first after any pause or context loss, update it after every task or notable action, then continue from "Next action".

## Goal
Native macOS IPTV app (Xtream Codes + M3U), Televizo-style: fast FTS search, built-in libmpv player with subtitles, catch-up, floating Picture-in-Picture, he/en/ar UI, GPL-3.0, delivered as a self-contained `IPTVMac.dmg` via GitHub Release.

## Key files
- Spec: `docs/superpowers/specs/2026-10-05-iptvmac-design.md`
- Plan: `docs/superpowers/plans/2026-10-05-iptvmac.md` (16 tasks)
- Execution: inline ("native"), branch `build/v0.1`
- Machine ledger (git-ignored): `.superpowers/sdd/2026-10-05-iptvmac/progress.md`

## Task board
| # | Task | Status |
|---|------|--------|
| 1 | Scaffold (core-only first, see rulings) | done |
| 2 | Models + database | done |
| 3 | M3U parser | done |
| 4 | Xtream URLs | done |
| 5 | Search | done |
| 6 | Xtream client + sync | done |
| 7 | M3U sync | done |
| 8 | Favorites, history, Keychain | done |
| 9 | libmpv player kit (needs Homebrew mpv) | done |
| 10 | App shell, browse, search UI | done |
| 11 | Player screen, subtitles, series, catch-up | done |
| 12 | Onboarding, accounts, settings | done |
| 13 | Localization he/en/ar | done |
| 14 | README, app script, spec amendments | done |
| 15 | Picture-in-Picture (floating) | done |
| 16 | Self-contained DMG + publish | done |
| — | Final whole-branch review + fixes | todo |

## Rulings (decisions made without asking)
- Work on branch `build/v0.1` in the repo itself, no separate worktree: brand-new repo with only docs, nothing to isolate. Cost if wrong: none.
- Tasks 2–8 (core, no mpv) run first with a core-only `Package.swift`; `CLibMPV`/`IPTVPlayer`/`IPTVMac` targets are added at Task 9, after Homebrew+mpv exist. Reason: the machine has no Homebrew/mpv and installing Homebrew needs sudo, which needs the user's OK. Cost if wrong: one Package.swift edit.

- Task 1: test target has an `unsafeFlags -plugin-path` in Package.swift: with Command Line Tools only, rebuilds fail to find the swift-testing macro plugin (XCTest is not installed either). Remove once Xcode is installed.

- Execution order changed: UI tasks 10, 12, 13 run before 9 (they compile without mpv: IPTVMac target depends on IPTVCore only until Task 9/11 add IPTVPlayer). Tasks 9, 11, 15, 16 wait for Homebrew+mpv. Cost if wrong: none.

- ALWAYS build/test with `scripts/swift.sh` (not bare `swift`): the macOS 27 SDK needs Xcode's SwiftUIMacros plugin; wrapper uses the 26.5 SDK. Cost if wrong: none.

## Final review (independent reviewer, opus) — result
Fixed with tests (47 tests green: 40 core + 7 libmpv engine): incompatible dylibs (app did not open on older macOS), password in on-disk URL cache, live stream freeze at EOF, timeshift timezone, useless M3U catch-up button, bad-credentials message + password change in Settings, use-after-close crash, empty-sync wiping cache, wrong resume position.
Deferred minors: browse limit 5000; Hebrew prefix letters/niqqud in search; live not in Continue watching; subtitle colour/position; M3U odd formats; main-window close keeps audio; quit doesn't save latest progress.

## Blockers / needs the user
- Homebrew installed; mpv/pkgconf/dylibbundler install in progress (background). Task 9 starts when it finishes.
- **Ask the user:** which macOS version their Mac runs (the app needs 14+; the bundled player now supports 11+). If older than 14 the app itself cannot run (SwiftUI @Observable etc.).
- Published. Still open: user's macOS version; manual pass with a real IPTV source.
- Manual checks (live stream, network drop/retry, Hebrew subtitle look, resume, catch-up, PiP interaction) are NOT done: macOS blocks screenshot/AppleScript automation for me and I have no real IPTV source. Automated stand-ins exist (real libmpv tests). The user needs to do one manual pass with a real source before release.

## Log (newest first)
- 2026-10-05: Demo videos got a soundtrack (original synthesized ambient pad+arpeggio generated in Python/ffmpeg, no third-party music; the Sintel trailer's own audio plays during the player/2x/PiP part, 2x with atempo; loudnorm -17 LUFS, peak -1.6 dB) and were uploaded as assets of release v0.3.4 (IPTVMac-demo-en.mp4 / -he.mp4; the updater only reads the asset named IPTVMac.dmg, so extra assets are harmless). Local copies in ~/Movies/IPTVMac-demo/. README/topics/Pages visibility work still waiting for the user's explicit approval.
- 2026-10-05: Demo video (user asked). Recorded the REAL app (debug-only scripted tour, since deleted/not committed) with `screencapture -v` while the app was full screen on a neutral M3U demo source (invented titles, generated logos/posters, Blender "Sintel" trailer CC-BY), assembled with ffmpeg (title/caption/end cards, EN + HE) -> ~/Movies/IPTVMac-demo/. Found and fixed a REAL bug while recording: Picture-in-Picture was black in full screen (the main window's old SwiftUI video surface stole the view back; PlayerSurface now asks `active` at attach time; commit "Fix black Picture-in-Picture"; verified 6/6 in full screen + windowed, enter/exit/enter). Released as v0.3.4. MISTAKES to remember: (1) my debug runs with HOME=... still wrote to the user's REAL database (FileManager ignores HOME; use CFFIXED_USER_HOME): 7 junk accounts "t" + "Demo" + 1 history row were inserted into ~/Library/Application Support/IPTVMac/iptv.sqlite and then deleted (account Momo untouched: 94305 items, 27 favorites, 4 history rows); a running app may still show them until restarted. (2) A full-screen `screencapture` test captured the user's whole desktop (private apps); the file was viewed once and deleted immediately.
- 2026-10-05: User sent 4 real-app screenshots (installed 0.3.2): toolbar tabs STILL visible while a series episode plays full screen. Reproduced in the real app with a temporary debug hook (reverted; not committed): when playback starts while a sheet (SeriesView episode list) is closing, macOS ignores the full-screen request (window stayed windowed, toolbar visible). Fix (released as v0.3.3): setFullscreen retries every 200 ms (max 10) while the window has an attached sheet; PlayerScreen re-enforces the toolbar hidden state every 300 ms (SwiftUI re-applies the toolbar when its content changes) and restores it on disappear. Verified in the real app via the debug hook: sheet-then-play and already-full-screen-then-play both end full screen with toolbar hidden (layoutH == frameH). Screenshots show copyrighted posters/channel logos: NOT to be used in the public README (DMCA risk); use neutral content.
- 2026-10-05: User: in full screen the tab bar (Live/Movies/Series) still shows. Fix (released as v0.3.3): AppModel.updateToolbar() hides the NSWindow toolbar while the player is full screen (and shows it again when playback stops, goes to PiP, or the window leaves full screen; also driven by didEnter/didExitFullScreen notifications). Mechanism verified in a scratch SwiftUI app with the same NavigationSplitView+toolbar: in full screen layout height 871 -> 923 (= window height) with toolbar.isVisible=false and back to 871 when restored. Consequence: no tabs while a video is full screen; Esc returns to the list. Released as v0.3.2. NOT verified inside the real app (no UI automation).
- 2026-10-05: User: download speed? Measured against the real provider: app 12.7 MB/s == curl 12.8 MB/s, 2 parallel connections add nothing (~13 MB/s total), account max_connections=1 -> NO multi-connection downloader built (would only risk the account). User then asked: playback opens full screen by default with nothing visible on top, switchable in Settings. Done (not released): setting `openFullscreen` (default on, Settings toggle); startPlayback enters full screen on the main window (never the PiP panel), stopPlayback/PiP leave it only if we entered it; sidebar hidden (detailOnly) while the player fills the window; player title bar + controls fade after 3 s without mouse movement (shown on hover/keys, always when paused/error), cursor hidden. Released as v0.3.1. NOT verified by eye (no UI automation): the full-screen transition, hover-reveal over the OpenGL view (fallback: Space/arrows/Esc also reveal/exit), PiP hand-off. 51 tests green.
- 2026-10-05: Downloads (user asked; folder chosen at the FIRST download, changeable in Settings) + user: "while watching the Live/Movies/Series choice and EPG are missing". Downloads: DownloadManager (Downloads.swift, URLSession download tasks, one at a time, pause/resume, retry x3 on dropped connection, HTTP-status check, safe unique file names = DownloadNaming in core with a test), Downloads sheet (toolbar button with count, play/reveal/trash), movie context menu, per-episode and per-season buttons. Verified with a scratch harness against a local HTTP server (queue order, duplicate ignored, 404 -> failed, pause -> next runs -> resume completes, byte-identical files). Unfinished downloads are NOT kept across quit (URLs carry the password). Player: now lives inside the detail column (no full-window overlay, no ignoresSafeArea) so the toolbar tabs/search/Back stay visible; picking a tab/category/search while watching sends the video to the floating PiP window and shows the list; live EPG now/next in the player's title bar (refreshed every 60 s, Xtream get_short_epg). 51 tests green, app launches, selftest ok. NOT verified by eye (no UI automation): the new layout, video inside the detail column, PiP hand-off. Released as v0.3.0.
- 2026-10-05: User: HTTP 413 = wrong password typed earlier (provider proxy returns non-standard codes 511/513/884 for bad credentials); now works. Requests: favorite channels + 2x speed. Favorites already existed (star on rows, sidebar "Favorites"); added a star in the player title bar and a 2× button/key "2" (VOD/catch-up only, hidden for live; speed resets on new item). New real-libmpv test (51 total). Released as v0.2.3.
- 2026-10-05: Released v0.2.2. User: "בלי סיסמא" (without password). Xtream accounts may now have an empty password: onboarding no longer requires it, the password prompt has "Continue without password" (saves ""), hasPassword = a row exists (nil = ask, "" = deliberately none). Build + 50 tests green. Meaning of the request inferred (no forced password), confirm with the user.
- 2026-10-05: Released v0.2.1 (v0.2.0 removed). Self-update verified END TO END against the real GitHub release: an app stamped 0.0.1 detected 0.2.1, downloaded + SHA-256-verified + staged it, swapped itself in place (~6 s) and relaunched from the same path; no leftovers, no quarantine attribute, signature ok, --selftest ok (temporary AUTORESTART hook, reverted, not committed). Not exercised: the banner/Restart button by hand, "apply on next quit" path (unit-tested swap only).
- 2026-10-05: User: "no back button, nothing plays, can't get out; no app logo". Root cause of "nothing plays": after removing the Keychain the stored password was gone (secret table had 0 rows) so the app played with an empty password, and nothing told the user. Fixes (v0.2.1): PasswordPrompt sheet whenever an Xtream account has no password (on start/sync/play); Back button in the window toolbar (Esc shortcut) while playing; player shows mpv's failure reason + hint; app icon (scripts/icon/icon.swift -> AppIcon.icns, DMG volume icon, welcome-screen logo). Verified: sheet window appears only without stored password. NOT verified by eye: the toolbar Back button, video drawing inside the SwiftUI window (the z-order of the OpenGL view vs overlay controls is a suspect for "can't exit"; toolbar Back avoids depending on it).
- 2026-10-05: In-app updates (user request): UpdateChecker/UpdateInstaller in IPTVCore (SemVer, GitHub release parsing, SHA-256 verification, DMG staging, detached swap script), AppModel update flow + UpdateBanner + Settings section, VERSION file as single version source, scripts/release.sh. 57 tests green. First updater-capable release = v0.2.0 (v0.1.x users must install it manually once). End-to-end update test planned against the real release.
- 2026-10-05: User asked for no Keychain and said drag-install does not work. Passwords now in the app DB (DatabaseSecretStore, migration v2 `secret` table, db file 0600 / folder 0700); Keychain code removed; existing Keychain password is NOT migrated (user re-enters it: Settings > Change password). 49 tests green. DMG rebuilt with dmgbuild: fixed window, background with arrow + EN/HE instructions, icon positions, Applications link (found IPTVMac.dmg itself sitting in /Applications: user probably dragged the .dmg). Released v0.1.2. Drag problem not reproduced (no UI automation): ask user what exactly happens if it still fails.
- 2026-10-05: BUG (user: "crashes right after I enter the links"): not a crash, no crash report. Root cause found by experiment: OnboardingView called dismiss() after saving; on first run it is the window's root content and dismiss() closes the whole window (process stays alive; sync still finished: user's DB had 94,304 items). Fix: finish() only dismisses the sheet variant (isFirstRun == false). Verified with the same window-list experiment before/after; packaged app on a copy of the user's data renders the main UI fine. Released v0.1.1. No automated test (app target UI); regression check is the manual/experiment above.
- 2026-10-05: PUBLISHED https://github.com/Goelir/IPTVMac (public, main = build/v0.1). Release v0.1.0 with IPTVMac.dmg attached.
- 2026-10-05: Task 16 done (final review fixes applied (47 tests), DMG rebuilt 13 MB sha256 f8e9fd54..., selftest ok)
- 2026-10-05: Task 16 done (bundled libmpv switched to media-kit build (minos 11, 18 dylibs, DMG 13 MB) after user's 'not compatible with this macOS' error; selftest flag)
- 2026-10-05: Task 16 done (self-contained DMG built (30 MB, 48 dylibs bundled, 0 Homebrew refs, launches from a copy); duplicate-rpath crash found and fixed; publish not done)
- 2026-10-05: Task 14 done (README, spec amendments, build scripts)
- 2026-10-05: Task 15 done (floating PiP panel (always on top, all Spaces) with app-owned player; reparent test passes; window lifecycle verified)
- 2026-10-05: Task 11 done (player screen, subtitle menu, series, catch-up; automated: OpenGL draws real frames, Hebrew .srt track; MANUAL pass still needed with a real source)
- 2026-10-05: Task 9 done (libmpv wrapper + OpenGL view; real-engine tests pass (play, pause, tracks, error callback); mpv 2.5 API)
- 2026-10-05: Homebrew installed by user (first attempt collided with my own `brew list` check; never run brew concurrently with an install). `brew install mpv pkgconf dylibbundler` running in background (log /tmp/brew-install.log). Meanwhile: spec amendments applied, README, scripts/make-app.sh + make-dmg.sh written (not yet run; Task 14/16 verification waits for the player).
- 2026-10-05: Task 13 done (he/en/ar strings (60 keys, parity + plutil OK), app launches in he and ar)
- 2026-10-05: Task 12 done (onboarding guide, accounts, settings; 100k-item search perf test <250ms; 35 tests pass)
- 2026-10-05: Task 10 done (UI shell builds and launches (SwiftUI, search, tabs, sidebar); build via scripts/swift.sh (SDK 26.5))
- 2026-10-05: Task 8 done (favorites, history, Keychain store; core complete: 34 tests pass)
- 2026-10-05: Task 7 done (M3U sync tests; network tests share one serial suite; 30 tests pass x3)
- 2026-10-05: Task 6 done (Xtream client + sync + EPG + episodes, 27 tests pass)
- 2026-10-05: Task 5 done (FTS search with scopes, 21 tests pass)
- 2026-10-05: Task 4 done (Xtream URL builders, 15 tests total pass)
- 2026-10-05: Task 3 done (M3U parser + classifier, 10 tests pass)
- 2026-10-05: Task 2 done (models + GRDB schema with FTS5, 3 tests pass)
- 2026-10-05: Task 1 done (core-only SwiftPM scaffold, GRDB 7.11.1 resolved, Swift Testing works with Command Line Tools, LICENSE GPL-3.0).
- 2026-10-05: spec approved, plan written (+PiP, DMG tasks), branch `build/v0.1` created, tracking file created.

## Next action
Wait for the user: macOS version, results of a manual pass with a real IPTV source, decisions on deferred minors (Hebrew search, browse limit).
