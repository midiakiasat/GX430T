#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$ROOT/../.." && pwd)"
CONFIG="$REPO_ROOT/config/product-version.env"

test -s "$CONFIG"

# shellcheck disable=SC1090
source "$CONFIG"

: "${GX430T_VERSION:?}"
: "${GX430T_BUILD:?}"

BUILD="$ROOT/build"
APP="$BUILD/GX430T Mac Control.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
MINIMUM_MACOS="13.0"

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES" "$BUILD/architectures"

SOURCES=()
while IFS= read -r SOURCE; do
  SOURCES+=("$SOURCE")
done < <(
  find "$ROOT/Sources" \
    -type f \
    -name '*.swift' \
    -print \
    | sort
)

test "${#SOURCES[@]}" -gt 0

echo "=== BUILD ARM64 ==="
swiftc "${SOURCES[@]}" \
  -parse-as-library \
  -sdk "$SDK" \
  -target "arm64-apple-macos${MINIMUM_MACOS}" \
  -o "$BUILD/architectures/GX430TMacControl-arm64" \
  -framework SwiftUI \
  -framework AppKit

echo "=== BUILD X86_64 ==="
swiftc "${SOURCES[@]}" \
  -parse-as-library \
  -sdk "$SDK" \
  -target "x86_64-apple-macos${MINIMUM_MACOS}" \
  -o "$BUILD/architectures/GX430TMacControl-x86_64" \
  -framework SwiftUI \
  -framework AppKit

echo "=== CREATE UNIVERSAL BINARY ==="
lipo -create \
  "$BUILD/architectures/GX430TMacControl-arm64" \
  "$BUILD/architectures/GX430TMacControl-x86_64" \
  -output "$MACOS/GX430TMacControl"

chmod 755 "$MACOS/GX430TMacControl"

cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"

/usr/libexec/PlistBuddy \
  -c "Set :CFBundleShortVersionString $GX430T_VERSION" \
  "$CONTENTS/Info.plist"

/usr/libexec/PlistBuddy \
  -c "Set :CFBundleVersion $GX430T_BUILD" \
  "$CONTENTS/Info.plist"

rsync -a \
  --exclude "Info.plist" \
  "$ROOT/Resources/" \
  "$RESOURCES/"

rm -rf "$BUILD/architectures"

test -f "$RESOURCES/ZEBRAGX430TLOGO.svg"
test -f "$RESOURCES/GX430TAppIcon.icns"

ARCHITECTURES="$(lipo -archs "$MACOS/GX430TMacControl")"

echo "GX430T_NATIVE_APP_ARCHITECTURES=$ARCHITECTURES"

echo "$ARCHITECTURES" | grep -qw arm64
echo "$ARCHITECTURES" | grep -qw x86_64

APP_VERSION="$(
  /usr/libexec/PlistBuddy \
    -c 'Print :CFBundleShortVersionString' \
    "$CONTENTS/Info.plist"
)"

APP_BUILD="$(
  /usr/libexec/PlistBuddy \
    -c 'Print :CFBundleVersion' \
    "$CONTENTS/Info.plist"
)"

test "$APP_VERSION" = "$GX430T_VERSION"
test "$APP_BUILD" = "$GX430T_BUILD"

echo "GX430T_NATIVE_APP_UNIVERSAL=true"
echo "GX430T_NATIVE_APP_VERSION=$APP_VERSION"
echo "GX430T_NATIVE_APP_BUILD=$APP_BUILD"
echo "GX430T_NATIVE_APP_BUILD_DONE=true"
echo "APP=$APP"
