<div align="center">

<img src="docs/logo.png" alt="IPTVMac logo" width="112">

# IPTVMac

**A native IPTV player for Mac, Windows, Android phones and Android TV.**<br>
Xtream Codes and M3U, instant search, a built-in player with subtitles, Picture in Picture, catch-up and downloads.<br>
Free and open source. No accounts, no analytics.

<br>

[![Latest release](https://img.shields.io/github/v/release/Goelir/IPTVMac?style=flat-square&color=5b6cf2&label=release)](https://github.com/Goelir/IPTVMac/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/Goelir/IPTVMac/total?style=flat-square&color=2ea44f)](https://github.com/Goelir/IPTVMac/releases)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue?style=flat-square)](LICENSE)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?style=flat-square&logo=apple)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-lightgrey?style=flat-square)
![Windows 10+](https://img.shields.io/badge/Windows-10%2B-0078d4?style=flat-square&logo=windows&logoColor=white)
![Android 8+](https://img.shields.io/badge/Android-8%2B-3ddc84?style=flat-square&logo=android&logoColor=white)
![Android TV](https://img.shields.io/badge/Android%20TV-Google%20TV%20%7C%20Fire%20TV-3ddc84?style=flat-square&logo=androidtv&logoColor=white)
[![Stars](https://img.shields.io/github/stars/Goelir/IPTVMac?style=flat-square&logo=github&color=eac54f)](https://github.com/Goelir/IPTVMac/stargazers)

[**Download for Mac**](https://github.com/Goelir/IPTVMac/releases/latest) &nbsp;|&nbsp; [**Download for Windows**](https://github.com/Goelir/IPTVMac/releases/tag/windows-v1.0.1) &nbsp;|&nbsp; [**Android and Android TV (APK)**](https://github.com/Goelir/IPTVMac/releases/tag/android-v1.0.4) &nbsp;|&nbsp; [**All downloads**](https://goelir.github.io/IPTVMac/download/)

If IPTVMac is useful to you, a ⭐ on GitHub helps others find it.

<sub>[Website](https://goelir.github.io/IPTVMac/) · [What's new](https://goelir.github.io/IPTVMac/changelog/) · [Install](#install) · [Features](#features) · [FAQ](#faq) · [עברית](README.he.md)</sub>

<br>

[![IPTVMac on macOS: a movie library with a Picture in Picture player, live channels and the full-screen player](docs/screenshots/hero-windows.png)](https://github.com/Goelir/IPTVMac/releases/download/v0.3.4/IPTVMac-demo-en.mp4)

<sub>Demo playlist with invented titles, video from the Blender Foundation's "Sintel" (CC-BY 3.0). [Watch the 80-second demo](https://github.com/Goelir/IPTVMac/releases/download/v0.3.4/IPTVMac-demo-en.mp4).</sub>

<!-- TODO: add a 5-10 s GIF (instant search, then Picture in Picture) as docs/images/demo.gif and show it here, for example: <img src="docs/images/demo.gif" alt="IPTVMac: instant search, then Picture in Picture" width="720"> -->

</div>

## Where it runs

| Device | Download | Status |
|---|---|---|
| **Mac** (Apple Silicon, macOS 14+) | [DMG or one-line install](#install) | Released, signed and notarized, updates itself |
| **Windows** (Windows 10 and 11, 64-bit) | [Installer or portable zip](https://github.com/Goelir/IPTVMac/releases/tag/windows-v1.0.1) (about 27 MB), unsigned: SmartScreen asks for More info, Run anyway | Keyboard and mouse player, downloads for offline viewing, light on memory and processor |
| **Android phones and tablets** (Android 8+) | [APK on GitHub Releases](https://github.com/Goelir/IPTVMac/releases/tag/android-v1.0.4) (`arm64-v8a` for almost every phone) | Released, install by hand |
| **Android TV, Google TV, Fire TV** | [32-bit or 64-bit APK](https://github.com/Goelir/IPTVMac/releases/tag/android-v1.0.4), installed with the Downloader app or a USB stick (see [Other platforms](#other-platforms)) | First version: remote control, no touch screen |
| **iPhone and iPad** | Waiting for App Store review; [build from source](#other-platforms) meanwhile | Not released |

The same engine, 31 languages and no-account design everywhere.

## Why IPTVMac

- **Fast.** Your whole library lives in a local SQLite database with full-text search. Typing finds a channel among 100,000 items in well under a second, in a category, in a section, or everywhere.
- **Stable.** Playback runs on [mpv](https://mpv.io) (libmpv, bundled). It plays the broken TS and HLS streams that trip up system players, reconnects when the stream drops, and uses hardware decoding.
- **Native, in the right language for each platform.** Swift and SwiftUI on Mac and iPhone; Dart with Flutter and a Kotlin layer on Android and Android TV. Each app is written for its own platform instead of one shared shell, and on every one the video is decoded by the same compiled libmpv engine; no Electron, no web view. Nothing else to install: the player is inside the app.
- **Open.** GPL-3.0, no accounts, no analytics. The app talks only to the servers you add, and to GitHub for updates.

## Install

**On Mac.** (Windows, Android and Android TV: see [Other platforms](#other-platforms).) Requires an Apple Silicon Mac (M1 or later) and macOS 14 or later.

**Install in one line.** Paste this in Terminal:

```
curl -fsSL https://raw.githubusercontent.com/Goelir/IPTVMac/main/install.sh | bash
```

It downloads the latest release, checks its signature and the SHA-256, copies IPTVMac to `/Applications` and opens it. [install.sh](install.sh) is short; read it first if you like. It works for every version, and because nothing is downloaded in a browser, macOS has nothing to flag. After this the app updates itself.

**Or download the DMG.** Get `IPTVMac.dmg` from the [latest release](https://github.com/Goelir/IPTVMac/releases/latest), open it and drag the **IPTVMac** icon onto the **Applications** icon in the window (not the .dmg file itself). From version 0.9.1, releases are signed with an Apple Developer ID and notarized (an automated malware scan by Apple, not a review of the app), so the app opens with a normal double-click. macOS may ask you once to confirm that it was downloaded from the internet.

Older versions are not notarized, and macOS blocks a browser-downloaded copy on first launch. For those:

- macOS 15 and later: try to open the app once, then go to **System Settings > Privacy & Security**, scroll down and click **Open Anyway** next to IPTVMac.
- Or in Terminal: `xattr -dr com.apple.quarantine /Applications/IPTVMac.app`

Prefer to see it first? [Watch the install guide (95 seconds)](https://youtu.be/TgaoFEEMg48).

## First run

The app opens a short three-step guide. You add a playlist from your provider:

- **Xtream Codes:** server address (for example `http://host:8080`), username and password. Your provider gives you these.
- **M3U:** a name and the playlist link.

IPTVMac is only a player. It does not include or host any channels, movies or series: you need a source you are allowed to use.

### No playlist yet?

If you do not have a provider, [iptv-org/iptv](https://github.com/iptv-org/iptv) is a free, independent open source project that publishes M3U playlists of publicly available channels from around the world. In IPTVMac choose **M3U**, give it a name and paste:

```
https://iptv-org.github.io/iptv/index.m3u
```

It holds about 11,000 entries (loading takes a moment); the project's README also lists playlists by country, language and category. IPTVMac is not affiliated with iptv-org. Whether a stream is available, and whether you may watch it, depends on the channel and on your country: use only what you are allowed to.

## Screenshots

<div align="center">

![Movies](docs/screenshots/03-movies.jpg)

| | |
|:---:|:---:|
| ![Live channels](docs/screenshots/01-live.jpg)<br>**Live channels** | ![Global search](docs/screenshots/02-search.jpg)<br>**Search everywhere** |
| ![Series](docs/screenshots/04-series.jpg)<br>**Series** | ![Player](docs/screenshots/05-player.jpg)<br>**Player** |
| ![Picture in Picture](docs/screenshots/06-pip.jpg)<br>**Picture in Picture** | ![Downloads](docs/screenshots/07-downloads.jpg)<br>**Downloads** |

<sub>The screenshots use an invented demo playlist; the video is the Blender Foundation's "Sintel" trailer (CC-BY 3.0).</sub>

</div>

## Android and Android TV

<p align="center">
<img src="docs/screenshots/android-live.webp" width="190" alt="IPTVMac on an Android phone: live channels with the program now and next">
<img src="docs/screenshots/android-series.webp" width="190" alt="IPTVMac on an Android phone: a series page with seasons and episodes">
<img src="docs/screenshots/tv-live.webp" width="330" alt="IPTVMac on Android TV: the channel list with the remote-control focus ring">
<img src="docs/screenshots/tv-details.webp" width="330" alt="IPTVMac on Android TV: a movie's details with Play focused">
</p>

<sub>Demo playlist with invented titles. The two TV pictures come from an emulator.</sub>

**Phone or tablet (Android 8 or later).**

1. Download [IPTVMac-Android-1.0.4-arm64-v8a.apk](https://github.com/Goelir/IPTVMac/releases/download/android-v1.0.4/IPTVMac-Android-1.0.4-arm64-v8a.apk) (it suits almost every phone; the [release page](https://github.com/Goelir/IPTVMac/releases/tag/android-v1.0.4) lists the other files).
2. Open it and allow installs from your browser or Files app when Android asks.
3. Add your source. A banner tells you when a newer version is out; installing it stays manual.

**Android TV, Google TV and Fire TV.**

1. On the TV install the **Downloader** app (Fire TV: search "Downloader"; Android TV and Google TV: Google Play) and open it.
2. In Downloader type the address of the file: [32-bit](https://github.com/Goelir/IPTVMac/releases/download/android-v1.0.4/IPTVMac-Android-1.0.4-tv-32bit.apk) (try this first, it runs on almost every TV and box) or [64-bit](https://github.com/Goelir/IPTVMac/releases/download/android-v1.0.4/IPTVMac-Android-1.0.4-tv-64bit.apk) (if the TV says the app is not compatible). A USB stick with the file works too.
3. Allow Downloader to install apps when the TV asks, install, and open IPTVMac. With the remote: arrows move, OK selects, Back goes up one level, **hold Back to close the app**.

More about every platform: [docs/PLATFORMS.md](docs/PLATFORMS.md).

## Features

| | |
|---|---|
| **Live, Movies, Series** | Three sections with categories, posters, channel logos, "Continue watching" and favorites. |
| **Search** | Type to search inside the current category, inside the section, or everywhere, with results grouped by section. Hebrew, Arabic and Latin text. |
| **Player** | Full screen by default; controls fade until you move the mouse. Space, arrows to skip (10 s by default, 5 to 60 s in Settings), `F` full screen, `2` double speed, `[` and `]` slower and faster, a speed picker from 0.25x to 4x (movies and episodes), `A` fit, fill or stretch, a **sleep timer** (moon icon), an optional clock, `Esc` to go back. |
| **Subtitles and audio** | Embedded tracks, external `.srt` and `.ass` files (menu or drag and drop), size and delay settings, preferred languages. |
| **Picture in Picture** | A floating mini player, always on top, that follows you across Spaces while you keep browsing. |
| **Catch-up** | Watch past programs on channels whose provider supports it (Xtream `tv_archive`), picked from the EPG. |
| **EPG** | Current and next program in the channel list and in the player (Xtream). |
| **Downloads** | Save movies and episodes (a whole season at once on Xtream series) to a folder you choose, and play them from the Downloads screen. |
| **Playlists** | Xtream Codes and M3U. With several playlists, switch from the toolbar, or choose **All playlists** to search, favorite and continue watching across all of them, with the playlist name on every item. |
| **Resume and next episode** | Movies and episodes continue where you stopped. When an episode ends, the next one starts after a 5-second countdown (cancel it, or turn it off). |
| **Settings** | System, light or dark appearance, interface language, automatic playlist refresh, hide categories by words, network buffer size, **backup and restore** of playlists (without passwords), favorites and watch history, and clearing history, favorites or the image cache. |
| **31 languages** | Includes right-to-left layout for Hebrew, Arabic, Persian and Urdu. See [Languages](#languages). |
| **Signed self-updates** | The app checks for new releases, verifies a signature and a SHA-256, and updates itself. See [Updates](#updates). |

## FAQ

<details>
<summary><b>macOS says the app "cannot be opened" or "is damaged".</b></summary>

This happens with older versions, which are not notarized (see [Install](#install)). Install the latest release: the DMG, or the install command above, which works for every version. To open an old copy anyway, go to **System Settings > Privacy & Security** and click **Open Anyway**, or run `xattr -dr com.apple.quarantine /Applications/IPTVMac.app`. If you see this message on the latest release, please open an issue.
</details>

<details>
<summary><b>Nothing plays, or I see "HTTP 4xx/5xx" (for example 403 or 413).</b></summary>

Check the username and password in **Settings** (**Change password**). Some providers answer wrong credentials or a blocked connection with unusual HTTP codes, such as 403 or 413, instead of a clear message. A typo in the password is the most common cause. The player also shows the reason mpv reports.
</details>

<details>
<summary><b>The update fails with a message about GitHub limiting requests, or "HTTP 403".</b></summary>

Versions before 0.7.2 asked the GitHub API for the latest release, and GitHub allows only 60 such requests per hour for each IP address, so a shared network can hit the limit. Version 0.7.2 reads a signed `release.txt` from github.com instead, which has no such limit, and says clearly when GitHub is limiting a network. If an older version cannot update, download `IPTVMac.dmg` from the [latest release](https://github.com/Goelir/IPTVMac/releases/latest) and replace the app in `/Applications`, or run the install command above. From then on it updates by itself.
</details>

<details>
<summary><b>Playback fails while a download is running.</b></summary>

Many providers allow a single connection per account (see `max_connections` in your account). Downloads run one at a time; avoid watching something else while one runs. Using more connections would not make it faster either: the speed is limited by the provider's line.
</details>

<details>
<summary><b>Why is 2x speed not available on live channels?</b></summary>

A live stream cannot run faster than real time. Speed works on movies, episodes and catch-up.
</details>

<details>
<summary><b>Intel Macs or older macOS?</b></summary>

Not supported: the bundled player is built for Apple Silicon (arm64) and the app needs macOS 14 or later.
</details>

<details>
<summary><b>Where is my data?</b></summary>

In `~/Library/Application Support/IPTVMac/` (the folder and database are readable by your user only). See [Privacy](#privacy).
</details>

## Languages

31 interface languages: Hebrew, English, Arabic, Spanish, French, German, Portuguese, Italian, Russian, Ukrainian, Polish, Romanian, Bulgarian, Dutch, Swedish, Czech, Hungarian, Greek, Albanian, Turkish, Persian, Urdu, Hindi, Bengali, Indonesian, Vietnamese, Thai, Chinese (Simplified and Traditional), Japanese and Korean, with right-to-left layout for Hebrew, Arabic, Persian and Urdu. The app follows your Mac's language, or you can pick one in Settings.

Apart from Hebrew, English and Arabic, the translations were written with AI help and no native speaker has reviewed them yet. Corrections are welcome, see below.

### Contributing translations

1. Copy `Sources/IPTVMac/Resources/en.lproj/Localizable.strings` to `<lang>.lproj/` (an Apple language code such as `pt` or `zh-Hans`) and translate the values. Keep every key and every `%@` / `%d` placeholder, in the same order.
2. Add the language, written in its own language, to `InterfaceLanguage.all` in `Sources/IPTVMac/AppPrefs.swift` (this fills the language picker in Settings).
3. Run `python3 scripts/check-strings.py <lang>`; it must print `OK`.

## Updates

The installed app checks GitHub Releases at launch and every 6 hours. When a newer version exists it downloads it and verifies the release **signature** (an Ed25519 key that is not stored on GitHub and is pinned in the app) and the SHA-256 published in the release notes. Then it shows a banner: **Restart to update** (or it installs on the next quit). Automatic checking and automatic download can each be turned off in Settings.

## Other platforms

Details for Windows, iPhone and iPad, Android and Android TV (downloads, install steps, how each app is built) are in [docs/PLATFORMS.md](docs/PLATFORMS.md); building from source and the technical details are in [docs/BUILDING.md](docs/BUILDING.md).

- **Windows:** [installer or portable zip](https://github.com/Goelir/IPTVMac/releases/tag/windows-v1.0.1) (Windows 10 or 11, 64-bit). Not signed with a paid certificate yet, so SmartScreen may warn: choose **More info**, then **Run anyway**.
- <a id="iphone-and-ipad"></a>**iPhone and iPad:** submitted to the App Store, waiting for review. To build it yourself see [docs/PLATFORMS.md](docs/PLATFORMS.md#windows-iphone-android-and-android-tv).
- **Android and Android TV:** see [the section above](#android-and-android-tv).

## Guides

- [How to watch Xtream Codes IPTV on a Mac](https://goelir.github.io/IPTVMac/guides/xtream-codes-on-mac.html)
- [How to play an M3U playlist on a Mac](https://goelir.github.io/IPTVMac/guides/m3u-playlist-on-mac.html)
- [Picture in Picture for IPTV on a Mac](https://goelir.github.io/IPTVMac/guides/picture-in-picture-iptv-mac.html)

## Privacy

Your sources are stored in `~/Library/Application Support/IPTVMac/` (readable by your user only). Account passwords are kept in that database in plain text; they are not in the Keychain (the Keychain asked for permission again with every new build). The app only contacts the servers you add, and GitHub for update checks. No analytics, no telemetry.

## Security

See [SECURITY.md](SECURITY.md) for how updates are protected, the known limits, and how to report a vulnerability privately.

## Contributing

Bug reports, translations and pull requests are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md). Never paste your server address, username or password in an issue.

To build from source, see [docs/BUILDING.md](docs/BUILDING.md).

## License

[GPL-3.0](LICENSE). IPTVMac is a media player and provides no content; you are responsible for using only sources you are authorized to access.

Third-party components, including the bundled libmpv: [docs/BUILDING.md](docs/BUILDING.md#third-party-components).
