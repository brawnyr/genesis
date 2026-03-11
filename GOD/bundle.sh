#!/bin/bash
# Build GOD and assemble into a proper macOS .app bundle
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="GOD"
BUNDLE_DIR="$SCRIPT_DIR/$APP_NAME.app"
CONTENTS="$BUNDLE_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

# Build
echo "building..."
swift build -c debug 2>&1 | tail -3

BINARY="$SCRIPT_DIR/.build/arm64-apple-macosx/debug/$APP_NAME"
if [ ! -f "$BINARY" ]; then
    echo "build failed — binary not found"
    exit 1
fi

# Assemble .app bundle
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS" "$RESOURCES"

# Copy binary
cp "$BINARY" "$MACOS/$APP_NAME"

# Copy entitlements and sign
codesign --force --sign - --entitlements "$SCRIPT_DIR/GOD/GOD.entitlements" "$MACOS/$APP_NAME" 2>/dev/null || true

# Info.plist
cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>GOD</string>
    <key>CFBundleIdentifier</key>
    <string>com.god.app</string>
    <key>CFBundleName</key>
    <string>GOD</string>
    <key>CFBundleDisplayName</key>
    <string>GOD</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>2.0</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>GOD needs microphone access for audio input.</string>
    <key>com.apple.security.device.audio-input</key>
    <true/>
</dict>
</plist>
PLIST

echo "bundled → $BUNDLE_DIR"

# Launch
if [ "${1:-}" = "--run" ]; then
    echo "launching..."
    open "$BUNDLE_DIR"
fi
