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

## Blockers / needs the user
- Homebrew installed; mpv/pkgconf/dylibbundler install in progress (background). Task 9 starts when it finishes.
- Task 16 publish step (GitHub repo + release) needs explicit user OK and `gh` auth.
- Manual checks (live stream, network drop/retry, Hebrew subtitle look, resume, catch-up, PiP interaction) are NOT done: macOS blocks screenshot/AppleScript automation for me and I have no real IPTV source. Automated stand-ins exist (real libmpv tests). The user needs to do one manual pass with a real source before release.

## Log (newest first)
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
Final whole-branch review; then ask the user: GitHub repo name/visibility for the release, and request a manual pass with a real IPTV source.
