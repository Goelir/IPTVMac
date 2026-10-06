#!/bin/bash
# Publishes the version in VERSION as GitHub release v<VERSION> with IPTVMac.dmg attached.
# Usage: scripts/release.sh path/to/release-notes.md
# The release notes get two final lines that installed apps and install.sh require:
#   SHA-256 of IPTVMac.dmg: `<hash>`        (detects a corrupted download)
#   Signature: `<base64>`                   (ssh-keygen -Y sign over "iptvmac-release\n<tag>\n<hash>\n", made with a key that is NOT on GitHub)
# so a stolen GitHub token alone cannot publish an installable update.
# The private key: ~/.ssh/iptvmac_release (override with IPTVMAC_RELEASE_KEY). See SECURITY.md.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="/opt/homebrew/bin:$PATH"
NOTES_FILE="${1:?usage: scripts/release.sh release-notes.md}"
VERSION="$(cat VERSION)"; TAG="v$VERSION"
KEY="${IPTVMAC_RELEASE_KEY:-$HOME/.ssh/iptvmac_release}"
[ -f "$KEY" ] || { echo "Signing key not found: $KEY (see SECURITY.md)"; exit 1; }
# What is released must be exactly a commit: an untracked file (a forgotten debug driver) would be compiled into the DMG.
[ -z "$(git status --porcelain --untracked-files=all)" ] || { echo "The working tree is not clean (untracked files count): commit or remove them first."; git status --short; exit 1; }
# The public key pinned in the app must be the one that matches the private key we sign with.
PUB="$(cut -d' ' -f2 scripts/release-key.pub)"
grep -q "$PUB" Sources/IPTVCore/ReleaseSignature.swift || { echo "scripts/release-key.pub is not the key pinned in ReleaseSignature.swift"; exit 1; }
grep -q "$PUB" install.sh || { echo "scripts/release-key.pub is not the key pinned in install.sh"; exit 1; }
[ "$(ssh-keygen -y -f "$KEY" | cut -d' ' -f2)" = "$PUB" ] || { echo "$KEY does not match scripts/release-key.pub"; exit 1; }
git push -q
COMMIT="$(git rev-parse HEAD)"
scripts/make-dmg.sh
SHA="$(shasum -a 256 build/IPTVMac.dmg | cut -c1-64)"
MSG="$(mktemp)"; trap 'rm -f "$MSG" "$MSG.sig" "$MSG.allowed"' EXIT
printf 'iptvmac-release\n%s\n%s\n' "$TAG" "$SHA" > "$MSG"
ssh-keygen -Y sign -q -f "$KEY" -n iptvmac-release "$MSG"
echo "iptvmac-release $(cut -d' ' -f1,2 scripts/release-key.pub)" > "$MSG.allowed"
ssh-keygen -Y verify -f "$MSG.allowed" -I iptvmac-release -n iptvmac-release -s "$MSG.sig" < "$MSG" > /dev/null   # never publish what we cannot verify
SIG="$(grep -v -- '-----' "$MSG.sig" | tr -d '\n')"
gh release create "$TAG" build/IPTVMac.dmg --target "$COMMIT" --title "IPTVMac $VERSION" \
  --notes "$(cat "$NOTES_FILE")

SHA-256 of IPTVMac.dmg: \`$SHA\`
Signature: \`$SIG\`"
echo "Released $TAG from commit ${COMMIT:0:8} ($SHA)"
