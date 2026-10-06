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
exit $fail
