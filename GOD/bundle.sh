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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>GOD needs microphone access for audio input.</string>
    <key>com.apple.security.device.audio-input</key>
    <true/>
</dict>
</plist>
PLIST

# Generate .icns from the app's programmatic icon
ICON_SCRIPT=$(cat << 'SWIFT'
import AppKit

let size: CGFloat = 512
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let bg = NSColor(red: 0.102, green: 0.098, blue: 0.090, alpha: 1)
let path = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size), xRadius: 100, yRadius: 100)
bg.setFill()
path.fill()

let letters: [[[Bool]]] = [
    [[false,true,true,true,true,true,false],[true,true,false,false,false,true,true],[true,true,false,false,false,false,false],[true,true,false,false,false,false,false],[true,true,false,true,true,true,false],[true,true,false,false,false,true,true],[true,true,false,false,false,true,true],[true,true,false,false,false,true,true],[false,true,true,true,true,true,false]],
    [[false,true,true,true,true,true,false],[true,true,false,false,false,true,true],[true,true,false,false,false,true,true],[true,true,false,false,false,true,true],[true,true,false,false,false,true,true],[true,true,false,false,false,true,true],[true,true,false,false,false,true,true],[true,true,false,false,false,true,true],[false,true,true,true,true,true,false]],
    [[true,true,true,true,true,false,false],[true,true,false,false,true,true,false],[true,true,false,false,false,true,true],[true,true,false,false,false,true,true],[true,true,false,false,false,true,true],[true,true,false,false,false,true,true],[true,true,false,false,false,true,true],[true,true,false,false,true,true,false],[true,true,true,true,true,false,false]]
]

let pixelSize: CGFloat = 14
let gap: CGFloat = 4
let cellSize = pixelSize + gap
let letterW = 7 * cellSize
let letterSpacing: CGFloat = 28
let totalW = 3 * letterW + 2 * letterSpacing
let totalH = 9 * cellSize
let startX = (size - totalW) / 2
let startY = (size - totalH) / 2
let orange = NSColor(red: 0.855, green: 0.482, blue: 0.290, alpha: 1)

for (li, letter) in letters.enumerated() {
    let lx = startX + CGFloat(li) * (letterW + letterSpacing)
    for (row, bits) in letter.enumerated() {
        for (col, on) in bits.enumerated() {
            guard on else { continue }
            let x = lx + CGFloat(col) * cellSize
            let y = startY + CGFloat(8 - row) * cellSize
            orange.setFill()
            NSRect(x: x, y: y, width: pixelSize, height: pixelSize).fill()
        }
    }
}

image.unlockFocus()

// Write PNG then convert to icns via iconutil
let tiffData = image.tiffRepresentation!
let bitmap = NSBitmapImageRep(data: tiffData)!
let pngData = bitmap.representation(using: .png, properties: [:])!

let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("god-icon-\(ProcessInfo.processInfo.processIdentifier)")
let iconsetDir = tmpDir.appendingPathComponent("AppIcon.iconset")
try! FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

// Write all required sizes
let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512)
]
for (name, px) in sizes {
    let resized = NSImage(size: NSSize(width: px, height: px))
    resized.lockFocus()
    image.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    resized.unlockFocus()
    let tiff = resized.tiffRepresentation!
    let bmp = NSBitmapImageRep(data: tiff)!
    let png = bmp.representation(using: .png, properties: [:])!
    try! png.write(to: iconsetDir.appendingPathComponent("\(name).png"))
}

// Print iconset path for the shell to use
print(iconsetDir.path)
SWIFT
)

ICONSET_DIR=$(echo "$ICON_SCRIPT" | swift -)
if [ -d "$ICONSET_DIR" ]; then
    iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES/AppIcon.icns"
    rm -rf "$(dirname "$ICONSET_DIR")"
    echo "icon → AppIcon.icns"
fi

echo "bundled → $BUNDLE_DIR"

# Launch
if [ "${1:-}" = "--run" ]; then
    echo "launching..."
    open "$BUNDLE_DIR"
fi
