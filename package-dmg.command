#!/bin/zsh

set -euo pipefail

ROOT_DIR="${0:A:h}"
APP_NAME="unquarantine"
VERSION="${1:-0.1.0}"
DIST_DIR="$ROOT_DIR/dist"
STAGING_DIR="$DIST_DIR/$APP_NAME-$VERSION"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"

mkdir -p "$DIST_DIR"
rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"

cp "$ROOT_DIR/unquarantine.command" "$STAGING_DIR/"
cp "$ROOT_DIR/README.md" "$STAGING_DIR/"
cp "$ROOT_DIR/LICENSE" "$STAGING_DIR/"
cp "$ROOT_DIR/unquarantine_icon.png" "$STAGING_DIR/"
cp "$ROOT_DIR"/Screenshot_*.png "$STAGING_DIR/"

chmod +x "$STAGING_DIR/unquarantine.command"

/usr/bin/hdiutil create \
  -volname "$APP_NAME $VERSION" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Created: $DMG_PATH"
