#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$PROJECT_ROOT/build/Work Mode.app"
if [[ ! -x "$APP_DIR/Contents/MacOS/WorkMode" ]]; then
    bash "$PROJECT_ROOT/scripts/build.sh"
fi
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")"
ARCHIVE="$PROJECT_ROOT/build/Work-Mode-$APP_VERSION-arm64.zip"
codesign --verify --strict "$APP_DIR"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ARCHIVE"
shasum -a 256 "$ARCHIVE"
printf 'Packaged: %s\n' "$ARCHIVE"
