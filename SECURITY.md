# Security

## Reporting a problem

Open a [private security advisory](https://github.com/Goelir/IPTVMac/security/advisories/new) on GitHub (or an issue without details if you prefer, and I will move the conversation to a private channel). Please do not post server addresses, usernames or passwords anywhere.

## How updates are protected

- Every release carries a SHA-256 of `IPTVMac.dmg` **and an Ed25519 signature** (`ssh-keygen -Y sign`, namespace `iptvmac-release`) over `iptvmac-release`, the tag and that checksum.
- The public key is pinned in the app (`Sources/IPTVCore/ReleaseSignature.swift`) and in `install.sh` (and listed in `scripts/release-key.pub`). The private key is **not** on GitHub: someone who takes over the GitHub account or token can edit a release, but cannot produce a signature the app or `install.sh` accepts.
- The app installs an update only if the signature is valid, the DMG comes from `github.com/Goelir/IPTVMac/releases/download/`, the checksum matches, the downloaded app has the same bundle identifier, is newer than the running one, and passes `codesign --verify`.
- `scripts/release.sh` refuses to release from a dirty working tree, signs, and verifies its own signature before publishing.

Known limits (honest list):

- The app is **not notarized** (no paid Apple Developer ID) and only ad-hoc signed, so macOS cannot tie it to a verified developer. The pinned release key is the trust root instead. Losing or leaking `~/.ssh/iptvmac_release` means rotating the key (a new app release signed with the old key that pins the new one).
- The player (libmpv/FFmpeg) is a prebuilt third-party build and processes data from your IPTV provider. HTTPS certificates of streams are verified; scripting (`ytdl`, Lua, config files) and embedded fonts are disabled. Keep the app updated.
- Xtream passwords are stored in plain text in the app's database (`~/Library/Application Support/IPTVMac/`, readable only by your user), not in the Keychain.

## Maintainer checklist

- Use a passkey/hardware-key 2FA for the GitHub account; keep branch protection (no force-push, no deletion) on `main`.
- Keep the signing key off shared machines; add a passphrase (`ssh-keygen -p -f ~/.ssh/iptvmac_release`) and load it with `ssh-add --apple-use-keychain` if you want it protected at rest.
- Re-pin the bundled libmpv (`scripts/make-app.sh`) when a newer, tested build is available.
