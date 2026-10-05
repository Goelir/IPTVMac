#!/bin/bash
# Builds build/IPTVMac.dmg: a Finder window with the app, an Applications shortcut, an arrow and instructions.
# dmgbuild writes the window layout directly (no Finder/AppleScript automation needed). Ad-hoc signed, not notarized.
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/make-app.sh
[ -x build/venv/bin/dmgbuild ] || { python3 -m venv build/venv && build/venv/bin/pip install -q dmgbuild; }
swift scripts/dmg/background.swift build/dmg-background.png
rm -f build/IPTVMac.dmg
build/venv/bin/dmgbuild -s scripts/dmg/settings.py -D app=build/IPTVMac.app -D background=build/dmg-background.png "IPTVMac" build/IPTVMac.dmg
ls -lh build/IPTVMac.dmg
