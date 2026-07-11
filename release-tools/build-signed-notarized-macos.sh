#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="${GX430T_VERSION:-0.3.0}"
APP_NAME="GX430T Mac Control"
APP_PATH="$ROOT/app/GX430TMacControl/build/$APP_NAME.app"
RELEASE_DIR="$ROOT/release"
UNSIGNED_PKG="$RELEASE_DIR/GX430T-Mac-Control-$VERSION.pkg"
SIGNED_PKG="$RELEASE_DIR/GX430T-Mac-Control-$VERSION-signed.pkg"
FINAL_PKG="$RELEASE_DIR/GX430T-Mac-Control-$VERSION-notarized.pkg"
APP_IDENTITY="${GX430T_DEVELOPER_ID_APPLICATION:-}"
INSTALLER_IDENTITY="${GX430T_DEVELOPER_ID_INSTALLER:-}"
NOTARY_PROFILE="${GX430T_NOTARY_PROFILE:-GX430T-NOTARY}"

mkdir -p "$RELEASE_DIR"

if [[ -z "$APP_IDENTITY" ]]; then
  APP_IDENTITY="$(
    security find-identity -v -p codesigning 2>/dev/null \
      | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' \
      | head -1
  )"
fi

if [[ -z "$INSTALLER_IDENTITY" ]]; then
  INSTALLER_IDENTITY="$(
    security find-identity -v -p basic 2>/dev/null \
      | sed -n 's/.*"\(Developer ID Installer:.*\)"/\1/p' \
      | head -1
  )"
fi

if [[ -z "$APP_IDENTITY" ]]; then
  echo "GX430T_DEVELOPER_ID_APPLICATION_REQUIRED=true"
  exit 2
fi

if [[ -z "$INSTALLER_IDENTITY" ]]; then
  echo "GX430T_DEVELOPER_ID_INSTALLER_REQUIRED=true"
  exit 2
fi

if ! xcrun notarytool history \
  --keychain-profile "$NOTARY_PROFILE" \
  >/dev/null 2>&1; then
  echo "GX430T_NOTARY_PROFILE_REQUIRED=true"
  echo "GX430T_EXPECTED_NOTARY_PROFILE=$NOTARY_PROFILE"
  exit 2
fi

echo "GX430T_VERSION=$VERSION"
echo "GX430T_APP_IDENTITY=$APP_IDENTITY"
echo "GX430T_INSTALLER_IDENTITY=$INSTALLER_IDENTITY"
echo "GX430T_NOTARY_PROFILE=$NOTARY_PROFILE"

echo "=== BUILD APP ==="
bash app/GX430TMacControl/build-app.sh

test -d "$APP_PATH"
test -x "$APP_PATH/Contents/MacOS/GX430TMacControl"

echo "=== REMOVE EXISTING SIGNATURE ==="
codesign --remove-signature "$APP_PATH" 2>/dev/null || true

echo "=== SIGN NESTED EXECUTABLES ==="
while IFS= read -r executable; do
  codesign \
    --force \
    --timestamp \
    --options runtime \
    --sign "$APP_IDENTITY" \
    "$executable"
done < <(
  find "$APP_PATH/Contents" \
    -type f \
    -perm -111 \
    ! -path "$APP_PATH/Contents/MacOS/GX430TMacControl" \
    -print
)

echo "=== SIGN APPLICATION ==="
codesign \
  --force \
  --deep \
  --timestamp \
  --options runtime \
  --sign "$APP_IDENTITY" \
  "$APP_PATH"

codesign --verify \
  --deep \
  --strict \
  --verbose=2 \
  "$APP_PATH"

codesign -dv --verbose=4 "$APP_PATH" 2>&1 \
  | grep -E 'Identifier=|Authority=|TeamIdentifier=|Runtime Version='

echo "=== VERIFY GATEKEEPER ASSESSMENT ==="
spctl \
  --assess \
  --type execute \
  --verbose=4 \
  "$APP_PATH"

echo "=== BUILD UNSIGNED COMPONENT PACKAGE ==="
GX430T_VERSION="$VERSION" bash installer/build-pkg.sh

test -f "$UNSIGNED_PKG"

echo "=== SIGN INSTALLER PACKAGE ==="
productsign \
  --sign "$INSTALLER_IDENTITY" \
  "$UNSIGNED_PKG" \
  "$SIGNED_PKG"

pkgutil --check-signature "$SIGNED_PKG"

echo "=== SUBMIT FOR NOTARIZATION ==="
xcrun notarytool submit \
  "$SIGNED_PKG" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait \
  --output-format json \
  | tee "$RELEASE_DIR/GX430T-Mac-Control-$VERSION-notary-result.json"

python3 - "$RELEASE_DIR/GX430T-Mac-Control-$VERSION-notary-result.json" <<'PY'
import json
import sys

record = json.load(open(sys.argv[1]))
status = str(record.get("status", "")).lower()

if status != "accepted":
    raise SystemExit(
        "GX430T_NOTARIZATION_NOT_ACCEPTED=true"
    )

print("GX430T_NOTARIZATION_ACCEPTED=true")
PY

echo "=== STAPLE NOTARIZATION TICKET ==="
cp "$SIGNED_PKG" "$FINAL_PKG"

xcrun stapler staple "$FINAL_PKG"
xcrun stapler validate "$FINAL_PKG"

echo "=== VERIFY FINAL PACKAGE ==="
pkgutil --check-signature "$FINAL_PKG"

shasum -a 256 "$FINAL_PKG" \
  > "$FINAL_PKG.sha256"

shasum -a 256 -c "$FINAL_PKG.sha256"

echo "GX430T_SIGNED_NOTARIZED_MACOS_PACKAGE=$FINAL_PKG"
echo "GX430T_SIGNED_NOTARIZED_MACOS_DISTRIBUTION_COMPLETE=true"
