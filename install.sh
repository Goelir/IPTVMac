#!/bin/bash
# IPTVMac installer. Usage:
#   curl -fsSL https://raw.githubusercontent.com/Goelir/IPTVMac/main/install.sh | bash
#
# Why this exists: IPTVMac is not notarized by Apple (that needs a paid Developer ID). A DMG downloaded in a
# browser is marked "from the internet" and macOS then blocks the app on first launch. A file fetched with curl is
# not marked, so the app installed by this script opens normally. Nothing is hidden: it downloads the latest
# GitHub release, checks the release SIGNATURE (made with a key that is not on GitHub) and the SHA-256, copies
# the app and opens it.
# INSTALL_DIR=/some/folder changes the destination (default: /Applications, or ~/Applications if /Applications is not writable).
set -euo pipefail

REPO="Goelir/IPTVMac"
NS="iptvmac-release"
SIGNER_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPYoXjKoZvOnw2h3ks4sAtdmjORMoYFi/2WOuO8q13sh"   # = scripts/release-key.pub

say() { printf '%s\n' "$*"; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

# Succeeds only if $3 (one-line base64 of an SSHSIG) signs the tag $1 and checksum $2 with the pinned key.
verify_signature() {
  local tag="$1" sha="$2" sig="$3" w rc=0
  w="$(mktemp -d)"
  printf 'iptvmac-release\n%s\n%s\n' "$tag" "$sha" > "$w/msg"
  { echo "-----BEGIN SSH SIGNATURE-----"; printf '%s' "$sig" | fold -w 70; echo; echo "-----END SSH SIGNATURE-----"; } > "$w/msg.sig"
  echo "$NS $SIGNER_KEY" > "$w/allowed"
  /usr/bin/ssh-keygen -Y verify -f "$w/allowed" -I "$NS" -n "$NS" -s "$w/msg.sig" < "$w/msg" > /dev/null 2>&1 || rc=$?
  rm -rf "$w"
  return "$rc"
}

main() {
  [ "$(id -u)" -ne 0 ] || die "do not run this as root (sudo): it installs IPTVMac for your own user."
  [ "$(uname -s)" = Darwin ] || die "IPTVMac runs on macOS only."
  [ "$(uname -m)" = arm64 ] || die "IPTVMac needs an Apple Silicon Mac (M1 or later)."
  [ "$(sw_vers -productVersion | cut -d. -f1)" -ge 14 ] || die "IPTVMac needs macOS 14 or later."

  local DEST
  if [ -n "${INSTALL_DIR:-}" ]; then
    DEST="$INSTALL_DIR"
    { [ -d "$DEST" ] && [ -w "$DEST" ]; } || die "INSTALL_DIR is not a writable folder: $DEST"
  elif [ -w /Applications ]; then
    DEST=/Applications
  else
    DEST="$HOME/Applications"; mkdir -p "$DEST"; say "/Applications is not writable: installing into $DEST"
  fi

  local WORK MNT
  WORK="$(mktemp -d)"; MNT="$WORK/mnt"
  trap 'hdiutil detach "'"$MNT"'" -quiet 2>/dev/null || true; rm -rf "'"$WORK"'"' EXIT

  say "Looking up the latest release..."
  local JSON URL SHA SIG TAG
  JSON="$(curl -fsSL -m 30 "https://api.github.com/repos/$REPO/releases/latest")" || die "cannot reach GitHub."
  # '|| true': with pipefail a missing match would end the script silently before the message below.
  URL="$(printf '%s' "$JSON" | grep -Eo '"browser_download_url": *"[^"]*/IPTVMac\.dmg"' | head -1 | sed -E 's/.*"(https[^"]*)"$/\1/')" || true
  SHA="$(printf '%s' "$JSON" | grep -Eo 'SHA-256 of IPTVMac\.dmg: `[0-9a-f]{64}`' | head -1 | grep -Eo '[0-9a-f]{64}')" || true
  SIG="$(printf '%s' "$JSON" | grep -Eo 'Signature: `[A-Za-z0-9+/=]{100,}`' | head -1 | grep -Eo '[A-Za-z0-9+/=]{100,}')" || true
  TAG="$(printf '%s' "$JSON" | grep -Eo '"tag_name": *"[^"]*"' | head -1 | sed -E 's/.*"([^"]*)"$/\1/')" || true
  [ -n "$URL" ] && [ -n "$SHA" ] && [ -n "$SIG" ] && [ -n "$TAG" ] || die "the latest release has no IPTVMac.dmg, checksum or signature. Nothing was installed."
  case "$URL" in "https://github.com/$REPO/releases/download/"*) ;; *) die "unexpected download address. Nothing was installed." ;; esac
  verify_signature "$TAG" "$SHA" "$SIG" || die "the release signature is NOT valid. Nothing was installed."

  say "Downloading IPTVMac $TAG..."
  curl -fL --progress-bar -o "$WORK/IPTVMac.dmg" "$URL" || die "download failed."
  [ "$(shasum -a 256 "$WORK/IPTVMac.dmg" | cut -c1-64)" = "$SHA" ] || die "checksum mismatch: the download is corrupted. Nothing was installed."

  mkdir -p "$MNT"
  hdiutil attach "$WORK/IPTVMac.dmg" -nobrowse -readonly -quiet -mountpoint "$MNT" || die "cannot open the disk image."
  [ -d "$MNT/IPTVMac.app" ] || die "IPTVMac.app is missing from the disk image."

  if pgrep -x IPTVMac >/dev/null 2>&1; then
    say "Closing the running IPTVMac..."; osascript -e 'tell application "IPTVMac" to quit' >/dev/null 2>&1 || true; sleep 2
  fi
  # Copy next to the destination first, then swap with renames: a failed copy (disk full, Ctrl-C) leaves the old app untouched.
  local NEW="$DEST/.IPTVMac.new.$$" OLD="$DEST/.IPTVMac.old.$$"
  rm -rf "$NEW"
  ditto "$MNT/IPTVMac.app" "$NEW" || { rm -rf "$NEW"; die "copy failed (disk full?). The existing installation was not changed."; }
  xattr -dr com.apple.quarantine "$NEW" 2>/dev/null || true
  if [ -e "$DEST/IPTVMac.app" ]; then
    mv "$DEST/IPTVMac.app" "$OLD" || { rm -rf "$NEW"; die "cannot replace the existing IPTVMac.app"; }
  fi
  if ! mv "$NEW" "$DEST/IPTVMac.app"; then
    [ -e "$OLD" ] && mv "$OLD" "$DEST/IPTVMac.app"
    die "installing failed; the previous version was restored."
  fi
  rm -rf "$OLD"

  say "Installed: $DEST/IPTVMac.app"
  if [ -z "${INSTALL_DIR:-}" ]; then open "$DEST/IPTVMac.app"; fi
}

# Everything runs inside main(): if a `curl | bash` download is cut short, bash has not yet seen the call to main and runs nothing.
[ -n "${IPTVMAC_INSTALL_SOURCE_ONLY:-}" ] || main "$@"
