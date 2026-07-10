#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/GX430T Mac Control.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"

swiftc "$ROOT/Sources/GX430TMacControl/main.swift" \
  -parse-as-library \
  -o "$MACOS/GX430TMacControl" \
  -framework SwiftUI \
  -framework AppKit

chmod 755 "$MACOS/GX430TMacControl"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"

echo "GX430T_NATIVE_APP_BUILD_DONE=true"
echo "APP=$APP"
