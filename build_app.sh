#!/usr/bin/env bash
set -euo pipefail

env CLANG_MODULE_CACHE_PATH=.build/ModuleCache SWIFTPM_HOME=.build/swiftpm swift build -c release

APP_DIR=".build/LivePhotoMaker.app"
EXECUTABLE_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
APP_VERSION="${APP_VERSION:-1.1.0}"
ICON_SOURCE="Assets/AppIcon.png"
DMG_BACKGROUND="Assets/DMGBackground.png"
ICONSET_DIR=".build/AppIcon.iconset"
ICNS_PATH="$RESOURCES_DIR/AppIcon.icns"
DIST_DIR=".build/dist"
DMG_STAGING_DIR=".build/dmg"
DMG_PATH="$DIST_DIR/LivePhotoMaker.dmg"
RW_DMG_PATH="$DIST_DIR/LivePhotoMaker-rw.dmg"

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
    <string>__APP_VERSION__</string>
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
perl -0pi -e "s/__APP_VERSION__/$APP_VERSION/g" "$APP_DIR/Contents/Info.plist"

if [[ ! -f "$DMG_BACKGROUND" ]]; then
    swift scripts/make_dmg_background.swift "$DMG_BACKGROUND"
fi

rm -rf "$DIST_DIR" "$DMG_STAGING_DIR"
mkdir -p "$DIST_DIR" "$DMG_STAGING_DIR/.background"
cp -R "$APP_DIR" "$DMG_STAGING_DIR/LivePhotoMaker.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"
cp "$DMG_BACKGROUND" "$DMG_STAGING_DIR/.background/background.png"
hdiutil create \
    -volname "LivePhotoMaker" \
    -srcfolder "$DMG_STAGING_DIR" \
    -ov \
    -format UDRW \
    "$RW_DMG_PATH" >/dev/null

MOUNT_OUTPUT="$(hdiutil attach "$RW_DMG_PATH" -readwrite -noverify -noautoopen)"
DMG_MOUNT_DIR="$(printf '%s\n' "$MOUNT_OUTPUT" | awk '/\/Volumes\// { print substr($0, index($0, "/Volumes/")); exit }')"
if [[ -z "$DMG_MOUNT_DIR" ]]; then
    echo "Could not find DMG mount point." >&2
    exit 1
fi

if osascript <<APPLESCRIPT
set bgPath to POSIX file "$DMG_MOUNT_DIR/.background/background.png" as alias
set didLayout to false
tell application "Finder"
    repeat 20 times
        try
            tell disk "LivePhotoMaker"
                open
                set current view of container window to icon view
                set toolbar visible of container window to false
                set statusbar visible of container window to false
                set bounds of container window to {120, 120, 760, 520}
                set theViewOptions to the icon view options of container window
                set arrangement of theViewOptions to not arranged
                set icon size of theViewOptions to 96
                set background picture of theViewOptions to bgPath
                set position of item "LivePhotoMaker.app" of container window to {176, 210}
                set position of item "Applications" of container window to {464, 210}
                close
            end tell
            set didLayout to true
            exit repeat
        on error
            delay 0.25
        end try
    end repeat
end tell
if didLayout is false then error "Could not customize DMG Finder layout."
APPLESCRIPT
then
    sync
else
    echo "Warning: Finder layout customization failed; DMG will still be usable." >&2
fi

hdiutil detach "$DMG_MOUNT_DIR" -quiet
hdiutil convert "$RW_DMG_PATH" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" >/dev/null
rm -f "$RW_DMG_PATH"

echo "Built $APP_DIR"
echo "Built $DMG_PATH"
