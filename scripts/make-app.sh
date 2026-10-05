#!/bin/bash
# Builds build/IPTVMac.app with libmpv and its dylibs bundled (no Homebrew needed on the target Mac).
# Requires on the build machine: brew install mpv pkgconf dylibbundler. Apple Silicon only.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="/opt/homebrew/bin:$PATH"
scripts/swift.sh build -c release
BIN="$(scripts/swift.sh build -c release --show-bin-path)"
APP=build/IPTVMac.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN/IPTVMac" "$APP/Contents/MacOS/IPTVMac"
cp -R "$BIN/IPTVMac_IPTVMac.bundle" "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>IPTVMac</string>
<key>CFBundleIdentifier</key><string>com.example.IPTVMac</string>
<key>CFBundleExecutable</key><string>IPTVMac</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>he</string><string>ar</string></array>
<key>NSHighResolutionCapable</key><true/>
<key>NSAppTransportSecurity</key><dict><key>NSAllowsArbitraryLoads</key><true/></dict>
</dict></plist>
PLIST
dylibbundler -od -b -x "$APP/Contents/MacOS/IPTVMac" -d "$APP/Contents/Frameworks" -p @executable_path/../Frameworks -s /opt/homebrew/lib
find "$APP/Contents/Frameworks" -name '*.dylib' -exec codesign --force --sign - {} \;
codesign --force --deep --sign - "$APP"
echo "Built $APP"
