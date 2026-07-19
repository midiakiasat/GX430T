#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT/config/product-version.env"

test -s "$CONFIG"

REQUESTED_VERSION="${GX430T_VERSION:-}"

# shellcheck disable=SC1090
source "$CONFIG"

VERSION="${REQUESTED_VERSION:-${GX430T_VERSION:?}}"
IDENTIFIER="${GX430T_IDENTIFIER:-com.kaaffilm.gx430t.mac-control}"
PKGROOT="$ROOT/installer/pkgroot"
RELEASE="$ROOT/release"
PKG="$RELEASE/GX430T-Mac-Control-$VERSION.pkg"

sudo chown -R \
  "$(id -un)":"$(id -gn)" \
  "$ROOT/app/GX430TMacControl" \
  "$ROOT/installer" \
  "$RELEASE" \
  2>/dev/null || true

sudo chmod -R \
  u+rwX \
  "$ROOT/app/GX430TMacControl" \
  "$ROOT/installer" \
  "$RELEASE" \
  2>/dev/null || true

rm -rf "$PKGROOT"

mkdir -p \
  "$PKGROOT/usr/local/gx430t" \
  "$PKGROOT/usr/local/bin" \
  "$PKGROOT/Applications" \
  "$RELEASE"

rsync -a \
  --exclude '.git' \
  --exclude '.DS_Store' \
  --exclude 'release' \
  --exclude 'installer/pkgroot' \
  --exclude 'app/GX430TMacControl/build' \
  --exclude 'DerivedData*' \
  --exclude '**/DerivedData*' \
  --exclude '**/build' \
  --exclude '**/.build' \
  --exclude '**/.swiftpm' \
  --exclude '**/xcuserdata' \
  --exclude '*.xcuserstate' \
  --exclude '__preview.dylib' \
  --exclude '*.debug.dylib' \
  "$ROOT/" \
  "$PKGROOT/usr/local/gx430t/"

bash "$ROOT/app/GX430TMacControl/build-app.sh"

rsync -a \
  "$ROOT/app/GX430TMacControl/build/GX430T Mac Control.app" \
  "$PKGROOT/Applications/"

chmod +x \
  "$PKGROOT/Applications/GX430T Mac Control.app/Contents/MacOS/GX430TMacControl" \
  "$PKGROOT/usr/local/gx430t/bin/gx430tctl"

test -d "$PKGROOT/Applications/GX430T Mac Control.app"

if test -e "$PKGROOT/usr/local/gx430t/GX430T Mac Control.app"; then
  echo "GX430T_DUPLICATE_SUPPORT_APPLICATION_IN_PACKAGE=true" >&2
  exit 1
fi

APPLICATION_COUNT="$(
  find "$PKGROOT" \
    -type d \
    -name '*.app' \
    -prune \
    -print |
  wc -l |
  tr -d ' '
)"

if test "$APPLICATION_COUNT" != "1"; then
  echo "GX430T_PACKAGE_APPLICATION_COUNT=$APPLICATION_COUNT" >&2
  exit 1
fi

find "$PKGROOT/usr/local/gx430t/scripts" \
  -type f \
  -name '*.sh' \
  -exec chmod +x {} +

find "$PKGROOT/usr/local/gx430t/install" \
  -type f \
  -name '*.sh' \
  -exec chmod +x {} +

ln -sfn \
  /usr/local/gx430t/bin/gx430tctl \
  "$PKGROOT/usr/local/bin/gx430tctl"

find "$PKGROOT" -depth -type d \
  \( \
    -name 'DerivedData*' \
    -o -name build \
    -o -name .build \
    -o -name .swiftpm \
    -o -name xcuserdata \
  \) \
  -exec rm -rf {} +

find "$PKGROOT" -type f \
  \( \
    -name '*.xcuserstate' \
    -o -name '__preview.dylib' \
    -o -name '*.debug.dylib' \
  \) \
  -delete

if find "$PKGROOT" \
  \( \
    -name 'DerivedData*' \
    -o -path '*/DerivedData*/*' \
    -o -path '*/.build/*' \
    -o -path '*/.swiftpm/*' \
    -o -path '*/xcuserdata/*' \
    -o -name '*.xcuserstate' \
    -o -name '__preview.dylib' \
    -o -name '*.debug.dylib' \
  \) \
  -print \
  -quit \
  | grep -q .; then
  echo "GX430T_GENERATED_BUILD_STATE_IN_PACKAGE=true" >&2
  exit 1
fi

rm -f "$PKG" "$PKG.sha256"

pkgbuild \
  --root "$PKGROOT" \
  --identifier "$IDENTIFIER" \
  --version "$VERSION" \
  --scripts "$ROOT/installer/scripts" \
  --install-location / \
  "$PKG"

shasum -a 256 "$PKG" > "$PKG.sha256"

echo "GX430T_PACKAGE_APPLICATION_COUNT=1"
echo "GX430T_APPLICATION_INSTALL_PATH=/Applications/GX430T Mac Control.app"
echo "GX430T_SUPPORT_APPLICATION_COPY=false"
echo "GX430T_PACKAGE_VERSION=$VERSION"
echo "GX430T_PKG_BUILD_DONE=true"
echo "PKG=$PKG"
echo "SHA256=$PKG.sha256"
