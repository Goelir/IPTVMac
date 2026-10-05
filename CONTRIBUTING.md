# Contributing

Thanks for helping. Bug reports, translations and pull requests are welcome.

## Reporting a bug

Open an issue and include: the IPTVMac version (Settings), your macOS version, whether the source is Xtream or M3U, and what you expected to happen. **Never paste your server address, username, password or playlist link**; replace them with `example`.

## Building

    brew install mpv pkgconf
    scripts/swift.sh test
    scripts/swift.sh run IPTVMac

`scripts/swift.sh` is needed only when Xcode is not installed (see README, "Build from source").

## Pull requests

- Keep a change focused; add or update a test in `Tests/` when you touch logic (the core is covered by Swift Testing tests, the player by real-libmpv tests).
- `scripts/swift.sh test` must pass.
- UI strings go in `Sources/IPTVMac/Resources/<lang>.lproj/Localizable.strings`, with the same keys in every language.

## Translations

Copy `Sources/IPTVMac/Resources/en.lproj/Localizable.strings` to `<lang>.lproj/`, translate the values, and open a pull request.

## License

By contributing you agree that your work is released under GPL-3.0, like the rest of the project.
