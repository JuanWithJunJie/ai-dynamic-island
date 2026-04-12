#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/.build/dev-app"
APP_DIR="$BUILD_DIR/MacIrland.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
PLIST_SOURCE="$ROOT/MacIrlandApp/Resources/Info.plist"
EXECUTABLE_SOURCE="$ROOT/.build/debug/MacIrland"
BUNDLE_ID="com.macirland.app"

swift build --package-path "$ROOT"

if pgrep -x "MacIrland" >/dev/null 2>&1; then
    osascript -e 'tell application id "com.macirland.app" to quit' >/dev/null 2>&1 || true
    pkill -x "MacIrland" >/dev/null 2>&1 || true
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
cp "$EXECUTABLE_SOURCE" "$MACOS_DIR/MacIrland"
cp "$PLIST_SOURCE" "$CONTENTS_DIR/Info.plist"
chmod +x "$MACOS_DIR/MacIrland"
codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP_DIR"

open "$APP_DIR"
