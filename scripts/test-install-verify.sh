#!/bin/bash
# Checks install.sh's signature verification with the real release key (needs ~/.ssh/iptvmac_release).
# Run: bash scripts/test-install-verify.sh
set -uo pipefail
cd "$(dirname "$0")/.."
KEY="${IPTVMAC_RELEASE_KEY:-$HOME/.ssh/iptvmac_release}"
IPTVMAC_INSTALL_SOURCE_ONLY=1 source ./install.sh
TAG=v9.9.9; SHA="$(printf 'a%.0s' $(seq 64))"
F="$(mktemp)"; trap 'rm -f "$F" "$F.sig"' EXIT
printf 'iptvmac-release\n%s\n%s\n' "$TAG" "$SHA" > "$F"
ssh-keygen -Y sign -q -f "$KEY" -n iptvmac-release "$F"
SIG="$(grep -v -- '-----' "$F.sig" | tr -d '\n')"
fail=0
check() { if [ "$1" = ok ] && "${@:2}"; then echo "ok   $2"; elif [ "$1" = bad ] && ! "${@:2}"; then echo "ok   rejected: $3 $4"; else echo "FAIL $*"; fail=1; fi; }
check ok  verify_signature "$TAG" "$SHA" "$SIG"
check bad verify_signature v9.9.8 "$SHA" "$SIG"                      # signature replayed on another tag
check bad verify_signature "$TAG" "${SHA/a/b}" "$SIG"                # signature replayed on another checksum
check bad verify_signature "$TAG" "$SHA" "AAAA$SIG"                  # garbage in front
check bad verify_signature "$TAG" "$SHA" ""                          # no signature
if [ "${1:-}" = live ]; then   # the same checks against the latest published release
  J="$(curl -fsSL https://api.github.com/repos/Goelir/IPTVMac/releases/latest)"
  LTAG="$(printf '%s' "$J" | grep -Eo '"tag_name": *"[^"]*"' | head -1 | sed -E 's/.*"([^"]*)"$/\1/')"
  LSHA="$(printf '%s' "$J" | grep -Eo 'SHA-256 of IPTVMac\.dmg: `[0-9a-f]{64}`' | grep -Eo '[0-9a-f]{64}')"
  LSIG="$(printf '%s' "$J" | grep -Eo 'Signature: `[A-Za-z0-9+/=]{100,}`' | grep -Eo '[A-Za-z0-9+/=]{100,}')"
  check ok  verify_signature "$LTAG" "$LSHA" "$LSIG"
  FIRST=0; [ "${LSHA:0:1}" = 0 ] && FIRST=1   # the checksum may itself start with 0: the edit must really change it
  check bad verify_signature "$LTAG" "${LSHA/[0-9a-f]/$FIRST}" "$LSIG"     # an edited checksum
  check bad verify_signature "v0.0.1" "$LSHA" "$LSIG"                      # an old tag with the new checksum
fi
exit $fail
