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

SOURCES=()
while IFS= read -r SOURCE; do
  SOURCES+=("$SOURCE")
done < <(find "$ROOT/Sources" -type f -name '*.swift' -print | sort)

test "${#SOURCES[@]}" -gt 0

swiftc "${SOURCES[@]}" \
  -parse-as-library \
  -o "$MACOS/GX430TMacControl" \
  -framework SwiftUI \
  -framework AppKit

chmod 755 "$MACOS/GX430TMacControl"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"

rsync -a \
  --exclude "Info.plist" \
  "$ROOT/Resources/" \
  "$RESOURCES/"

test -f "$RESOURCES/ZEBRAGX430TLOGO.svg"

echo "GX430T_NATIVE_APP_BUILD_DONE=true"
echo "APP=$APP"
