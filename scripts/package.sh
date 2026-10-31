#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$PROJECT_ROOT/build/Work Mode.app"
# A previous build may exist even when sources or Info.plist have changed.
# Always rebuild so the archive matches the current checkout and version.
bash "$PROJECT_ROOT/scripts/build.sh"
# Keep the release asset name stable for /releases/latest/download links.
ARCHIVE="$PROJECT_ROOT/build/Work-Mode-arm64.zip"
codesign --verify --strict "$APP_DIR"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ARCHIVE"
(cd "$PROJECT_ROOT/build" && shasum -a 256 "Work-Mode-arm64.zip" > SHA256SUMS.txt)
cat "$PROJECT_ROOT/build/SHA256SUMS.txt"
printf 'Packaged: %s\n' "$ARCHIVE"
