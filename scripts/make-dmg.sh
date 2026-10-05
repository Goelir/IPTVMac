#!/bin/bash
# Builds build/IPTVMac.dmg (drag IPTVMac.app to Applications). Ad-hoc signed, not notarized.
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/make-app.sh
STAGE=build/dmg-stage
rm -rf "$STAGE" build/IPTVMac.dmg
mkdir -p "$STAGE"
cp -R build/IPTVMac.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "IPTVMac" -srcfolder "$STAGE" -ov -format UDZO build/IPTVMac.dmg
rm -rf "$STAGE"
ls -lh build/IPTVMac.dmg
