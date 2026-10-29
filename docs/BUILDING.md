# Building IPTVMac, and the technical details

How IPTVMac is built on each platform, what it is written in, and which third-party components it ships. For what the app does and how to install it, see the [README](../README.md). Details per platform (downloads, install steps) are in [PLATFORMS.md](PLATFORMS.md).

## What each platform is written in

| Device | Get it | Status | Written in |
|---|---|---|---|
| **Mac** (Apple Silicon, macOS 14+) | [DMG or one-line install](../README.md#install) | Released, signed and notarized, updates itself | Swift + SwiftUI |
| **Windows** (Windows 10 and 11, 64-bit) | [Installer or portable zip](https://github.com/Goelir/IPTVMac/releases/tag/windows-v1.0.1) (about 27 MB), unsigned: SmartScreen asks for More info, Run anyway | Keyboard and mouse player, downloads for offline viewing, light on memory and processor | Dart + Flutter, small C++ shell |
| **Android phones and tablets** (Android 8+) | [APK on GitHub Releases](https://github.com/Goelir/IPTVMac/releases/tag/android-v1.0.4) (`arm64-v8a` for almost every phone) | Released, install by hand | Dart + Flutter, Kotlin layer |
| **Android TV, Google TV, Fire TV** | [32-bit or 64-bit APK](https://github.com/Goelir/IPTVMac/releases/tag/android-v1.0.4), installed with the Downloader app or a USB stick (see [Other platforms](PLATFORMS.md)) | First version: remote control, no touch screen | Dart + Flutter, Kotlin layer |
| **iPhone and iPad** | Waiting for App Store review; [build from source](PLATFORMS.md) meanwhile | Not released | Swift + SwiftUI |

The same engine, 31 languages and no-account design everywhere. On every platform the video is decoded by the same compiled libmpv engine.

## Mac (Swift and SwiftUI)

    brew install mpv pkgconf     # mpv only supplies the C headers to compile against
    scripts/swift.sh test        # tests
    scripts/swift.sh run IPTVMac # run
    scripts/make-dmg.sh          # builds build/IPTVMac.dmg

Use `scripts/swift.sh` instead of bare `swift` when only Command Line Tools are installed (it selects an SDK whose SwiftUI does not need Xcode's macro plugin). Design notes are in [docs/superpowers/specs](superpowers/specs/2026-10-05-iptvmac-design.md).

## iPhone and iPad (Swift and SwiftUI)

Build with `scripts/ios-setup.sh`, then open `ios/IPTVPhone.xcodeproj` (see [ios/README.md](../ios/README.md)). The app is submitted to the App Store and waiting for review.

## Android and Android TV (Dart and Flutter, with a Kotlin layer)

    cd flutter && flutter pub get && flutter test && flutter build apk

Flutter 3.47, JDK 17, Android SDK 36; see [flutter/PLAN.md](../flutter/PLAN.md). The Android app and the Android TV app are the same code. The Android app checks github.com for newer `android-v` releases at most every six hours, and Settings can switch that off.

## Windows (Dart and Flutter, with a small C++ shell)

The Windows app is the same Flutter code as Android, in `flutter/` (the runner is in `flutter/windows/`). Flutter cannot build Windows from a Mac, so the build runs on GitHub Actions: `.github/workflows/windows.yml`, on a Windows machine, in this order:

1. `flutter analyze` and the whole test suite (`flutter test`).
2. An integration test of the download engine on Windows (`integration_test/downloads_windows_test.dart`: a file is fetched from a local server, saved and checked for size).
3. `flutter build windows --release`, then the Visual C++ runtime DLLs are copied next to the app, so a clean Windows can start it.
4. A start-up check: the app is started, left for 40 seconds, its memory and idle processor use are measured, and a screenshot is saved.
5. The portable zip, the installer (Inno Setup, `flutter/windows/installer/IPTVMac.iss`: for the current user, no administrator rights) and `SHA256SUMS.txt`. The installer is also installed, started and uninstalled once.

Run it by hand from the Actions tab, or push a tag `windows-vX.Y.Z`; the release is made from the artifacts. To build on your own Windows machine you need Flutter and Visual Studio with the "Desktop development with C++" workload: `cd flutter && flutter pub get && flutter test && flutter build windows --release`. The app checks github.com for newer `windows-v` releases, like the Android app.

## Third-party components

The release bundles prebuilt [libmpv](https://mpv.io) (mpv 0.36 built with `-Dgpl=false` and FFmpeg 6 configured with `--enable-version3` but not `--enable-gpl`, so the libraries are LGPL) from [media-kit/libmpv-darwin-build](https://github.com/media-kit/libmpv-darwin-build) v0.7.3 (sha256 `9bb168ec908b4801f4231f411e3278a0aea644a2b03ce375c880d2813ab7f949`). `scripts/make-app.sh` downloads and verifies it; source for those components is available from the projects linked above. Search and storage use [GRDB.swift](https://github.com/groue/GRDB.swift) (MIT). Demo footage: "Sintel" © Blender Foundation, [CC-BY 3.0](https://durian.blender.org).
