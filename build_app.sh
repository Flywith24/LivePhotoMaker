#!/usr/bin/env bash
set -euo pipefail

env CLANG_MODULE_CACHE_PATH=.build/ModuleCache SWIFTPM_HOME=.build/swiftpm swift build -c release

APP_DIR=".build/LivePhotoMaker.app"
EXECUTABLE_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
ICON_SOURCE="Assets/AppIcon.png"
ICONSET_DIR=".build/AppIcon.iconset"
ICNS_PATH="$RESOURCES_DIR/AppIcon.icns"
DIST_DIR=".build/dist"
DMG_STAGING_DIR=".build/dmg"
DMG_PATH="$DIST_DIR/LivePhotoMaker.dmg"

rm -rf "$APP_DIR"
mkdir -p "$EXECUTABLE_DIR" "$RESOURCES_DIR"
cp ".build/release/LivePhotoMaker" "$EXECUTABLE_DIR/LivePhotoMaker"

if [[ -f "$ICON_SOURCE" ]]; then
    rm -rf "$ICONSET_DIR"
    mkdir -p "$ICONSET_DIR"

    sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
    sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
    sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
    sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
    sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
    sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
    sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
    sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
    sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
    sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null

    iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"
fi

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>LivePhotoMaker</string>
    <key>CFBundleIdentifier</key>
    <string>local.livephotomaker.app</string>
    <key>CFBundleName</key>
    <string>LivePhotoMaker</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPhotoLibraryAddUsageDescription</key>
    <string>LivePhotoMaker adds converted Live Photos to your Photos library.</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>LivePhotoMaker needs Photos access to add converted Live Photos.</string>
</dict>
</plist>
PLIST

rm -rf "$DIST_DIR" "$DMG_STAGING_DIR"
mkdir -p "$DIST_DIR" "$DMG_STAGING_DIR"
cp -R "$APP_DIR" "$DMG_STAGING_DIR/LivePhotoMaker.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"
hdiutil create \
    -volname "LivePhotoMaker" \
    -srcfolder "$DMG_STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

echo "Built $APP_DIR"
echo "Built $DMG_PATH"
