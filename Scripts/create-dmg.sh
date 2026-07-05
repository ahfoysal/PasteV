#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="PasteV"
VERSION="${VERSION:-0.1.3}"
APP_PATH="${APP_PATH:-$HOME/Applications/${APP_NAME}.app}"
RELEASE_DIR="$ROOT_DIR/Releases"
STAGING_DIR="$ROOT_DIR/.build/dmg"
DMG_PATH="$RELEASE_DIR/${APP_NAME}-${VERSION}.dmg"

if [[ ! -d "$APP_PATH" ]]; then
    "$ROOT_DIR/Scripts/build-app.sh" >/dev/null
fi

rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR" "$RELEASE_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/${APP_NAME}.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

echo "$DMG_PATH"
