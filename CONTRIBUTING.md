# Contributing to IPTVMac

Thanks for helping. Bug reports, translations and pull requests are all welcome.

## Reporting a bug

Open an [issue](https://github.com/Goelir/IPTVMac/issues/new/choose) and include the IPTVMac version (Settings), your macOS version, whether the source is Xtream or M3U, the steps that lead to the problem, and what you expected to happen.

**Never paste your server address, username, password or playlist link**, in the issue text or in a screenshot. Replace them with `example`. For a security problem, use the private route in [SECURITY.md](SECURITY.md) instead.

## Suggesting a feature

Open a feature request and describe what you want to do, and how you do it today if you do. A real situation helps more than a finished design.

## Building

    brew install mpv pkgconf
    scripts/swift.sh test
    scripts/swift.sh run IPTVMac

`scripts/swift.sh` is needed only when Xcode is not installed (see the README, "Build from source"). The code is split in four targets: `IPTVCore` (data, search, Xtream and M3U, updater), `IPTVPlayer` (libmpv), `IPTVMac` (the SwiftUI app) and `CLibMPV` (the C headers).

## Pull requests

- Keep a change focused; one pull request, one purpose.
- Add or update a test in `Tests/` when you touch logic. The core is covered by Swift Testing tests, the player by real-libmpv tests.
- `scripts/swift.sh test` must pass.
- UI strings go in `Sources/IPTVMac/Resources/<lang>.lproj/Localizable.strings`, with the same keys in every language.
- Do not add analytics, telemetry or network calls to servers other than the ones the user adds and GitHub (update checks).
- Do not add posters, logos or footage you do not have the right to share. The demo content is invented, and the video is the Blender Foundation's "Sintel" (CC-BY 3.0).

## Translations

1. Copy `Sources/IPTVMac/Resources/en.lproj/Localizable.strings` to `<lang>.lproj/` (an Apple language code such as `pt` or `zh-Hans`) and translate the values. Keep every key and every `%@` / `%d` placeholder, in the same order.
2. Add one row for the language, written in its own language, to `InterfaceLanguage.all` in `Sources/IPTVMac/AppPrefs.swift`.
3. Run `python3 scripts/check-strings.py <lang>` (it checks the keys and the placeholders); it must print `OK`. Then open a pull request.

Except for Hebrew, English and Arabic, the current translations were written with AI help and no native speaker has reviewed them. A fix to a single wrong word is a good first contribution.

## Releasing (maintainers)

Bump `VERSION`, commit, and run `scripts/release.sh notes.md`. It refuses to run from a dirty tree, builds, signs and verifies the release signature before publishing (see [SECURITY.md](SECURITY.md)).

## License

By contributing you agree that your work is released under GPL-3.0, like the rest of the project.
