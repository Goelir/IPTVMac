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
| 2 | Models + database | todo |
| 3 | M3U parser | todo |
| 4 | Xtream URLs | todo |
| 5 | Search | todo |
| 6 | Xtream client + sync | todo |
| 7 | M3U sync | todo |
| 8 | Favorites, history, Keychain | todo |
| 9 | libmpv player kit (needs Homebrew mpv) | todo |
| 10 | App shell, browse, search UI | todo |
| 11 | Player screen, subtitles, series, catch-up | todo |
| 12 | Onboarding, accounts, settings | todo |
| 13 | Localization he/en/ar | todo |
| 14 | README, app script, spec amendments | todo |
| 15 | Picture-in-Picture (floating) | todo |
| 16 | Self-contained DMG + publish | todo |
| — | Final whole-branch review + fixes | todo |

## Rulings (decisions made without asking)
- Work on branch `build/v0.1` in the repo itself, no separate worktree: brand-new repo with only docs, nothing to isolate. Cost if wrong: none.
- Tasks 2–8 (core, no mpv) run first with a core-only `Package.swift`; `CLibMPV`/`IPTVPlayer`/`IPTVMac` targets are added at Task 9, after Homebrew+mpv exist. Reason: the machine has no Homebrew/mpv and installing Homebrew needs sudo, which needs the user's OK. Cost if wrong: one Package.swift edit.

- Task 1: test target has an `unsafeFlags -plugin-path` in Package.swift: with Command Line Tools only, rebuilds fail to find the swift-testing macro plugin (XCTest is not installed either). Remove once Xcode is installed.

## Blockers / needs the user
- Homebrew + `mpv pkgconf dylibbundler` must be installed before Task 9 (Homebrew install runs a remote script with sudo). Will ask when Task 9 starts.
- Task 16 publish step (GitHub repo + release) needs explicit user OK and `gh` auth.
- Manual checks (real stream playback, subtitles, catch-up, PiP) need a real IPTV source from the user.

## Log (newest first)
- 2026-10-05: Task 1 done (core-only SwiftPM scaffold, GRDB 7.11.1 resolved, Swift Testing works with Command Line Tools, LICENSE GPL-3.0).
- 2026-10-05: spec approved, plan written (+PiP, DMG tasks), branch `build/v0.1` created, tracking file created.

## Next action
Task 2: models + AppDatabase (TDD).
