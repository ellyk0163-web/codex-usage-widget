#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
APP_BUNDLE="$BUILD_DIR/CodexUsageWidget.app"
EXECUTABLE="$APP_BUNDLE/Contents/MacOS/CodexUsageWidget"

rm -rf "$APP_BUNDLE"
mkdir -p "$(dirname "$EXECUTABLE")"

xcrun clang -fobjc-arc -framework Cocoa -framework CoreGraphics -framework ApplicationServices \
  "$PROJECT_ROOT/Sources/CodexUsageWidget.m" \
  -o "$EXECUTABLE"

cp "$PROJECT_ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
codesign --force --sign - --timestamp=none "$APP_BUNDLE"

printf 'Built %s\n' "$APP_BUNDLE"
