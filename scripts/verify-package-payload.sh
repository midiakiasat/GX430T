#!/usr/bin/env bash
set -euo pipefail

PKG="${1:-}"

if [[ -z "$PKG" ]]; then
  echo "usage: verify-package-payload.sh <package.pkg>" >&2
  exit 64
fi

test -f "$PKG"

PAYLOAD="$(pkgutil --payload-files "$PKG")"

printf '%s\n' "$PAYLOAD" \
  | grep -F './Applications/GX430T Mac Control.app/Contents/MacOS/GX430TMacControl' \
  >/dev/null

printf '%s\n' "$PAYLOAD" \
  | grep -F './usr/local/gx430t/bin/gx430tctl' \
  >/dev/null

printf '%s\n' "$PAYLOAD" \
  | grep -F './usr/local/gx430t/bin/gx430t-update' \
  >/dev/null

printf '%s\n' "$PAYLOAD" \
  | grep -F './usr/local/gx430t/updater/gx430t_updater.py' \
  >/dev/null

if printf '%s\n' "$PAYLOAD" \
  | grep -E '/(DerivedData|DerivedDataDevice|\.build|\.swiftpm|xcuserdata)(/|$)|\.xcuserstate$'; then
  echo "GX430T_PACKAGE_CONTAINS_GENERATED_DEVELOPMENT_STATE=true" >&2
  exit 1
fi

if printf '%s\n' "$PAYLOAD" \
  | grep -E '/Debug-(iphoneos|iphonesimulator)/.*\.app(/|$)'; then
  echo "GX430T_PACKAGE_CONTAINS_GENERATED_IPHONE_APPLICATION=true" >&2
  exit 1
fi

echo "GX430T_PACKAGE_PAYLOAD_VERIFY_PASS=true"
