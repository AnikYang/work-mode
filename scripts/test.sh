#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$PROJECT_ROOT/build"
xcrun swiftc -swift-version 5 -target arm64-apple-macos14.0 \
    -framework AppKit -framework Carbon -framework IOKit \
    "$PROJECT_ROOT/Sources/PowerManager.swift" \
    "$PROJECT_ROOT/Sources/Shortcut.swift" \
    "$PROJECT_ROOT/Sources/HotKeyManager.swift" \
    "$PROJECT_ROOT/Sources/FocusKeyRemapper.swift" \
    "$PROJECT_ROOT/Tests/main.swift" -o "$PROJECT_ROOT/build/WorkModeTests"
"$PROJECT_ROOT/build/WorkModeTests"
