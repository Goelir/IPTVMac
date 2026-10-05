# IPTVMac

A native macOS IPTV player for Xtream Codes and M3U sources. Fast search, built-in libmpv player with subtitles, catch-up, floating Picture-in-Picture, Hebrew/English/Arabic UI. GPL-3.0.

## Install

Download `IPTVMac.dmg` from the Releases page, open it and drag IPTVMac to Applications. Nothing else to install: the video player (libmpv) is inside the app.

The app is not notarized (no Apple Developer ID), so macOS blocks the first launch. To open it:

- macOS 15 and later: try to open the app once, then go to **System Settings > Privacy & Security**, scroll down and click **Open Anyway** next to IPTVMac.
- Or in Terminal: `xattr -dr com.apple.quarantine /Applications/IPTVMac.app`

Apple Silicon (M1 or later) and macOS 14 or later only. You can check that the bundled player works with `/Applications/IPTVMac.app/Contents/MacOS/IPTVMac --selftest` (prints the mpv version and exits 0).

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
