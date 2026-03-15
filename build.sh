#!/bin/bash
# AudioPilot build script
# Compiles the Swift Package and wraps it into a proper macOS .app bundle.
# Requirements: Xcode Command Line Tools (xcode-select --install)
# Tested on macOS 13+
set -e

APP_NAME="AudioPilot"
BUNDLE_ID="com.personal.audiopilot"
VERSION="1.0.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔨 Compiling $APP_NAME …"
swift build -c release 2>&1

EXEC_PATH=".build/release/$APP_NAME"
if [ ! -f "$EXEC_PATH" ]; then
    echo "❌ Build failed – executable not found at $EXEC_PATH"
    exit 1
fi

APP_BUNDLE="$APP_NAME.app"
echo "📦 Creating app bundle …"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$EXEC_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# ── App Icon ──────────────────────────────────────────────────────────────────
if [ -f "$SCRIPT_DIR/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

# ── Info.plist ────────────────────────────────────────────────────────────────
cat > "$APP_BUNDLE/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
</dict>
</plist>
PLIST

# ── PkgInfo ───────────────────────────────────────────────────────────────────
printf 'APPL????' > "$APP_BUNDLE/Contents/PkgInfo"

# ── Ad-hoc code sign ──────────────────────────────────────────────────────────
echo "✍️  Signing with ad-hoc signature …"
codesign --sign - --force --deep "$APP_BUNDLE"

echo ""
echo "✅  $APP_BUNDLE is ready."
echo ""
echo "To open right now:"
echo "  open \"$SCRIPT_DIR/$APP_BUNDLE\""
echo ""
echo "To install to /Applications:"
echo "  cp -r \"$SCRIPT_DIR/$APP_BUNDLE\" /Applications/"
echo ""
echo "⚠️  First launch: right-click → Open to bypass Gatekeeper."
