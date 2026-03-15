#!/bin/bash
# AudioPilot distribution script
# Creates a DMG that friends can open and drag to /Applications.
# Usage: bash dist.sh
set -e

APP_NAME="AudioPilot"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 1. Build the .app bundle
echo "🔨 Building …"
bash build.sh

# 2. Prepare staging folder
STAGING=$(mktemp -d)
cp -r "$APP_NAME.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# 3. Create compressed DMG
DMG_PATH="$SCRIPT_DIR/${APP_NAME}.dmg"
rm -f "$DMG_PATH"

echo "📀 Creating DMG …"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING"

echo ""
echo "✅  ${APP_NAME}.dmg is ready for distribution."
echo ""
echo "Recipients install it by:"
echo "  1. Opening ${APP_NAME}.dmg"
echo "  2. Dragging ${APP_NAME} to Applications"
echo "  3. Right-click → Open on first launch (Gatekeeper bypass)"
echo ""
echo "File: $DMG_PATH"
