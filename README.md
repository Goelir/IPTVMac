# IPTVMac

A native macOS IPTV player for Xtream Codes and M3U sources. Fast search, built-in libmpv player with subtitles, catch-up, floating Picture-in-Picture, Hebrew/English/Arabic UI. GPL-3.0.

## Install

**Easiest (no warning from macOS).** Paste this line in Terminal:

```
curl -fsSL https://raw.githubusercontent.com/Goelir/IPTVMac/main/install.sh | bash
```

It downloads the latest release, checks the SHA-256 published in the release notes, copies IPTVMac to `/Applications` and opens it. Why it works: IPTVMac is not notarized (that needs a paid Apple Developer ID), and macOS blocks apps that a browser marked as "downloaded from the internet". A file fetched with `curl` is not marked, so there is nothing to bypass. Read [install.sh](install.sh) first if you like; it is short. After this, the app updates itself.

**Or by hand.** Download `IPTVMac.dmg` from the Releases page, open it and drag the **IPTVMac** icon onto the **Applications** icon in the window (not the .dmg file itself). Nothing else to install: the video player (libmpv) is inside the app. The first launch is blocked by macOS, so:

- macOS 15 and later: try to open the app once, then go to **System Settings > Privacy & Security**, scroll down and click **Open Anyway** next to IPTVMac.
- Or in Terminal: `xattr -dr com.apple.quarantine /Applications/IPTVMac.app`

Apple Silicon (M1 or later) and macOS 14 or later only. You can check that the bundled player works with `/Applications/IPTVMac.app/Contents/MacOS/IPTVMac --selftest` (prints the mpv version and exits 0).

## Updates

The installed app checks GitHub Releases at launch and every 6 hours. When a newer version exists it downloads it, verifies the SHA-256 published in the release notes, and shows a banner: **Restart to update** (or it installs on the next quit). Both automatic checking and automatic download can be turned off in Settings. To publish a new version: bump `VERSION`, commit, and run `scripts/release.sh notes.md`.

## Privacy

Your sources are stored in `~/Library/Application Support/IPTVMac/` (readable by your user only). Account passwords are kept in that database in plain text; they are not in the Keychain. The app only contacts the servers you add.

## First run

The app opens a 3-step guide. Xtream Codes: server address (`http://host:8080`), username, password. M3U: a name and the playlist link.

## Third-party components

The release bundles prebuilt [libmpv](https://mpv.io) (mpv 0.36, ffmpeg 6, GPL build) from [media-kit/libmpv-darwin-build](https://github.com/media-kit/libmpv-darwin-build) v0.7.3 (sha256 `9bb168ec908b4801f4231f411e3278a0aea644a2b03ce375c880d2813ab7f949`). `scripts/make-app.sh` downloads and verifies it; source for those components is available from the projects linked above. Search and storage use [GRDB.swift](https://github.com/groue/GRDB.swift) (MIT).

## Build from source

    brew install mpv pkgconf     # mpv only supplies the C headers to compile against
    scripts/swift.sh test        # core tests
    scripts/swift.sh run IPTVMac # run
    scripts/make-dmg.sh          # builds build/IPTVMac.dmg

Use `scripts/swift.sh` instead of bare `swift` when only Command Line Tools are installed (it selects an SDK whose SwiftUI does not need Xcode's macro plugin).

## Contributing translations

Copy `Sources/IPTVMac/Resources/en.lproj/Localizable.strings` to `<lang>.lproj/` and translate the values.
