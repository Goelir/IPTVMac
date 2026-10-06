#!/bin/bash
# Builds build/IPTVMac.app with a prebuilt libmpv bundled (nothing to install on the target Mac, macOS 14+, Apple Silicon).
#
# The player library is the media-kit "libmpv-darwin-build" release (mpv 0.36 + ffmpeg 6, built for macOS 11+, GPL).
# Homebrew's mpv is NOT bundled: its bottles require the macOS version of the build machine (27), so the app would not
# open on older Macs. Homebrew's mpv is still used at build time for the C headers and to link against.
# Requires on the build machine: brew install mpv pkgconf
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="/opt/homebrew/bin:$PATH"

# Single source of the app version: the VERSION file (IPTVMAC_VERSION overrides it for update tests).
VERSION="${IPTVMAC_VERSION:-$(cat VERSION)}"
MK_VERSION=v0.7.3
MK_NAME="libmpv-libs_${MK_VERSION}_macos-arm64-video-full"
MK_SHA256=9bb168ec908b4801f4231f411e3278a0aea644a2b03ce375c880d2813ab7f949
VENDOR=build/vendor
if [ ! -d "$VENDOR/$MK_NAME" ]; then
  mkdir -p "$VENDOR"
  curl -fsSL -o "$VENDOR/mk.tgz" "https://github.com/media-kit/libmpv-darwin-build/releases/download/$MK_VERSION/$MK_NAME.tar.gz"
  echo "$MK_SHA256  $VENDOR/mk.tgz" | shasum -a 256 -c -
  tar xzf "$VENDOR/mk.tgz" -C "$VENDOR"
fi

scripts/swift.sh build -c release
BIN="$(scripts/swift.sh build -c release --show-bin-path)"
APP=build/IPTVMac.app
EXE="$APP/Contents/MacOS/IPTVMac"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN/IPTVMac" "$EXE"
cp -R "$BIN/IPTVMac_IPTVMac.bundle" "$APP/Contents/Resources/"
cp "$VENDOR/$MK_NAME"/*.dylib "$APP/Contents/Frameworks/"

# Point the executable at the bundled libmpv instead of Homebrew's, and resolve @rpath dependencies inside the app.
OLD="$(otool -L "$EXE" | awk '/libmpv/ {print $1; exit}')"
install_name_tool -change "$OLD" "@rpath/libmpv.dylib" "$EXE"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$EXE"
# The prebuilt dylibs carry build-machine rpaths (/nix/store/...) that do not exist anywhere else.
for f in "$APP"/Contents/Frameworks/*.dylib; do
  for rp in $(otool -l "$f" | awk '/path \/nix\/store/ {print $2}'); do install_name_tool -delete_rpath "$rp" "$f"; done
done

# App icon: drawn by scripts/icon/icon.swift, packed into an .icns.
ICONSET=build/AppIcon.iconset
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
swift scripts/icon/icon.swift build/icon-1024.png 1024
for sz in 16 32 128 256 512; do
  sips -z $sz $sz build/icon-1024.png --out "$ICONSET/icon_${sz}x${sz}.png" >/dev/null
  sips -z $((sz*2)) $((sz*2)) build/icon-1024.png --out "$ICONSET/icon_${sz}x${sz}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>IPTVMac</string>
<key>CFBundleIdentifier</key><string>io.github.goelir.IPTVMac</string>
<key>CFBundleExecutable</key><string>IPTVMac</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>__VERSION__</string>
<key>CFBundleVersion</key><string>__VERSION__</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>he</string><string>ar</string></array>
<key>NSHighResolutionCapable</key><true/>
<key>NSAppTransportSecurity</key><dict><key>NSAllowsArbitraryLoads</key><true/></dict>
</dict></plist>
PLIST
sed -i '' "s/__VERSION__/$VERSION/g" "$APP/Contents/Info.plist"
find "$APP/Contents/Frameworks" -name '*.dylib' -exec codesign --force --sign - {} \;
codesign --force --deep --sign - "$APP"
echo "Built $APP"
