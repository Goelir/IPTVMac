#!/bin/bash
# Publishes the version in VERSION as GitHub release v<VERSION> with IPTVMac.dmg attached.
# Usage: scripts/release.sh path/to/release-notes.md
# The release notes get a final line "SHA-256 of IPTVMac.dmg: `<hash>`": installed apps update themselves only from
# releases that carry this line (see UpdateChecker.parse), and verify the download against it.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="/opt/homebrew/bin:$PATH"
NOTES_FILE="${1:?usage: scripts/release.sh release-notes.md}"
VERSION="$(cat VERSION)"
git diff --quiet && git diff --cached --quiet || { echo "Commit your changes first."; exit 1; }
git push -q
scripts/make-dmg.sh
SHA="$(shasum -a 256 build/IPTVMac.dmg | cut -c1-64)"
gh release create "v$VERSION" build/IPTVMac.dmg --title "IPTVMac $VERSION" \
  --notes "$(cat "$NOTES_FILE")

SHA-256 of IPTVMac.dmg: \`$SHA\`"
echo "Released v$VERSION ($SHA)"
