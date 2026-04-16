#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/.build/release"
APP_DIR="$BUILD_DIR/MacIrland.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PLIST_SOURCE="$ROOT/MacIrlandApp/Resources/Info.plist"
BUNDLE_ID="com.macirland.app"

# Version from Info.plist
VERSION=$(grep -o '<string>[0-9]*\.[0-9]*\.[0-9]*</string>' "$PLIST_SOURCE" | head -1 | sed 's/<[^>]*>//g')
BUILD=$(grep -o '<string>[0-9]*</string>' "$PLIST_SOURCE" | tail -1 | sed 's/<[^>]*>//g')

echo "Building MacIrland v${VERSION} (build ${BUILD})"

# Clean and build release
rm -rf "$APP_DIR"
swift build --configuration release --package-path "$ROOT"

# Create app bundle structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp "$ROOT/.build/arm64-apple-macosx/release/MacIrland" "$MACOS_DIR/MacIrland"
chmod +x "$MACOS_DIR/MacIrland"

# Copy Info.plist
cp "$PLIST_SOURCE" "$CONTENTS_DIR/Info.plist"

# Copy app icon if exists
if [ -f "$ROOT/MacIrlandApp/Resources/AppIcon.icns" ]; then
    cp "$ROOT/MacIrlandApp/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Copy Scripts (hook script)
mkdir -p "$RESOURCES_DIR/Scripts"
if [ -f "$ROOT/MacIrlandKit/Scripts/macirland-hook.py" ]; then
    cp "$ROOT/MacIrlandKit/Scripts/macirland-hook.py" "$RESOURCES_DIR/Scripts/"
fi
chmod +x "$RESOURCES_DIR/Scripts/"* 2>/dev/null || true

# Sign app (ad-hoc if no certificate)
if [ -n "${CODE_SIGN_ID:-}" ]; then
    echo "Signing with certificate: $CODE_SIGN_ID"
    codesign --force --deep --sign "$CODE_SIGN_ID" --identifier "$BUNDLE_ID" "$APP_DIR"
else
    echo "No CODE_SIGN_ID set, skipping signature"
    codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP_DIR"
fi

# Create zip
cd "$BUILD_DIR"
rm -f MacIrland-v${VERSION}-macos.zip
zip -r "MacIrland-v${VERSION}-macos.zip" "MacIrland.app"
echo ""
echo "Release artifact: $BUILD_DIR/MacIrland-v${VERSION}-macos.zip"
echo "Size: $(du -h MacIrland-v${VERSION}-macos.zip | cut -f1)"
