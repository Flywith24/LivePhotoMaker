#!/usr/bin/env bash
set -euo pipefail

env CLANG_MODULE_CACHE_PATH=.build/ModuleCache SWIFTPM_HOME=.build/swiftpm swift build -c release

APP_DIR=".build/LivePhotoMaker.app"
EXECUTABLE_DIR="$APP_DIR/Contents/MacOS"

rm -rf "$APP_DIR"
mkdir -p "$EXECUTABLE_DIR"
cp ".build/release/LivePhotoMaker" "$EXECUTABLE_DIR/LivePhotoMaker"

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

echo "Built $APP_DIR"
