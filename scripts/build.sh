#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
APP_DIR="$BUILD_DIR/Work Mode.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

xcrun swiftc -swift-version 5 -O -whole-module-optimization \
    -target arm64-apple-macos14.0 \
    -framework AppKit -framework SwiftUI -framework Carbon -framework IOKit \
    "$PROJECT_ROOT"/Sources/*.swift -o "$APP_DIR/Contents/MacOS/WorkMode"
cp "$PROJECT_ROOT/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
xcrun swift "$PROJECT_ROOT/scripts/GenerateIcon.swift" "$BUILD_DIR/AppIcon.iconset"
iconutil -c icns "$BUILD_DIR/AppIcon.iconset" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP_DIR"
codesign --verify --strict "$APP_DIR"
printf 'Built: %s\n' "$APP_DIR"
