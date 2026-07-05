#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="PasteV"
VERSION="${VERSION:-0.1.2}"
BUILD_CONFIG="${BUILD_CONFIG:-release}"
APP_DIR="$ROOT_DIR/.build/${APP_NAME}.app"
INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications/${APP_NAME}.app}"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"
"$ROOT_DIR/Scripts/generate-assets.py" >/dev/null
mkdir -p "$ROOT_DIR/.build/$BUILD_CONFIG"
clang -fobjc-arc \
    -framework AppKit \
    -framework ApplicationServices \
    -framework Carbon \
    "$ROOT_DIR/SourcesObjC/PasteV.m" \
    -o "$ROOT_DIR/.build/$BUILD_CONFIG/$APP_NAME"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$ROOT_DIR/.build/$BUILD_CONFIG/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/Assets/PasteV.icns" "$RESOURCES_DIR/PasteV.icns"
cp "$ROOT_DIR/Assets/StatusIconTemplate.png" "$RESOURCES_DIR/StatusIconTemplate.png"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>dev.foysal.pastev</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>PasteV</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>PasteV uses paste actions to insert a selected clipboard item into the app you were using.</string>
</dict>
</plist>
PLIST

codesign --force --sign - --identifier "dev.foysal.pastev" "$APP_DIR" >/dev/null
rm -rf "$INSTALL_DIR"
mkdir -p "$(dirname "$INSTALL_DIR")"
cp -R "$APP_DIR" "$INSTALL_DIR"
codesign --force --deep --sign - --identifier "dev.foysal.pastev" "$INSTALL_DIR" >/dev/null

echo "$INSTALL_DIR"
