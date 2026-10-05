#!/bin/bash
# IPTVMac installer. Usage:
#   curl -fsSL https://raw.githubusercontent.com/Goelir/IPTVMac/main/install.sh | bash
#
# Why this exists: IPTVMac is not notarized by Apple (that needs a paid Developer ID). A DMG downloaded in a
# browser is marked "from the internet" and macOS then blocks the app on first launch. A file fetched with curl is
# not marked, so the app installed by this script opens normally. Nothing is hidden: it downloads the latest
# GitHub release, checks the SHA-256 published in the release notes, copies the app and opens it.
# INSTALL_DIR=/some/folder changes the destination (default: /Applications, or ~/Applications if not writable).
set -euo pipefail

REPO="Goelir/IPTVMac"
say() { printf '%s\n' "$*"; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = Darwin ] || die "IPTVMac runs on macOS only."
[ "$(uname -m)" = arm64 ] || die "IPTVMac needs an Apple Silicon Mac (M1 or later)."
[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 14 ] || die "IPTVMac needs macOS 14 or later."

DEST="${INSTALL_DIR:-/Applications}"
if [ ! -w "$DEST" ]; then DEST="$HOME/Applications"; mkdir -p "$DEST"; fi

WORK="$(mktemp -d)"
MNT="$WORK/mnt"
cleanup() { hdiutil detach "$MNT" -quiet 2>/dev/null || true; rm -rf "$WORK"; }
trap cleanup EXIT

say "Looking up the latest release..."
JSON="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest")" || die "cannot reach GitHub."
URL="$(printf '%s' "$JSON" | grep -Eo '"browser_download_url": *"[^"]*/IPTVMac\.dmg"' | head -1 | sed -E 's/.*"(https[^"]*)"$/\1/')"
SHA="$(printf '%s' "$JSON" | grep -Eo 'SHA-256 of IPTVMac\.dmg: `[0-9a-f]{64}`' | head -1 | grep -Eo '[0-9a-f]{64}')"
TAG="$(printf '%s' "$JSON" | grep -Eo '"tag_name": *"[^"]*"' | head -1 | sed -E 's/.*"([^"]*)"$/\1/')"
[ -n "$URL" ] && [ -n "$SHA" ] || die "the latest release has no IPTVMac.dmg or no published checksum."

say "Downloading IPTVMac $TAG..."
curl -fL --progress-bar -o "$WORK/IPTVMac.dmg" "$URL" || die "download failed."
[ "$(shasum -a 256 "$WORK/IPTVMac.dmg" | cut -c1-64)" = "$SHA" ] || die "checksum mismatch: the download is corrupted. Nothing was installed."

mkdir -p "$MNT"
hdiutil attach "$WORK/IPTVMac.dmg" -nobrowse -readonly -quiet -mountpoint "$MNT" || die "cannot open the disk image."
[ -d "$MNT/IPTVMac.app" ] || die "IPTVMac.app is missing from the disk image."

if pgrep -x IPTVMac >/dev/null 2>&1; then say "Closing the running IPTVMac..."; osascript -e 'tell application "IPTVMac" to quit' >/dev/null 2>&1 || true; sleep 2; fi
rm -rf "$DEST/IPTVMac.app"
ditto "$MNT/IPTVMac.app" "$DEST/IPTVMac.app"
xattr -dr com.apple.quarantine "$DEST/IPTVMac.app" 2>/dev/null || true

say "Installed: $DEST/IPTVMac.app"
if [ -z "${INSTALL_DIR:-}" ]; then open "$DEST/IPTVMac.app"; fi
