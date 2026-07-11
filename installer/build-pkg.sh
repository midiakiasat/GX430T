#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${GX430T_VERSION:-0.1.0}"
IDENTIFIER="${GX430T_IDENTIFIER:-com.kaaffilm.gx430t.mac-control}"
PKGROOT="$ROOT/installer/pkgroot"
RELEASE="$ROOT/release"
PKG="$RELEASE/GX430T-Mac-Control-$VERSION.pkg"

sudo chown -R "$(id -un)":"$(id -gn)" "$ROOT/app/GX430TMacControl" "$PKGROOT" "$RELEASE" 2>/dev/null || true
sudo chmod -R u+rwX "$ROOT/app/GX430TMacControl" "$PKGROOT" "$RELEASE" 2>/dev/null || true
rm -rf "$PKGROOT"

mkdir -p "$PKGROOT/usr/local/gx430t" "$PKGROOT/usr/local/bin" "$PKGROOT/Applications" "$RELEASE"

rsync -a \
  --exclude ".git" \
  --exclude "release" \
  --exclude "installer/pkgroot" \
  --exclude "app/GX430TMacControl/build" \
  "$ROOT/" "$PKGROOT/usr/local/gx430t/"

bash "$ROOT/app/GX430TMacControl/build-app.sh"

rsync -a "$ROOT/app/GX430TMacControl/build/GX430T Mac Control.app" "$PKGROOT/usr/local/gx430t/"
rsync -a "$ROOT/app/GX430TMacControl/build/GX430T Mac Control.app" "$PKGROOT/Applications/"

chmod +x "$PKGROOT/usr/local/gx430t/GX430T Mac Control.app/Contents/MacOS/GX430TMacControl"
chmod +x "$PKGROOT/Applications/GX430T Mac Control.app/Contents/MacOS/GX430TMacControl"
chmod +x "$PKGROOT/usr/local/gx430t/bin/gx430tctl"
chmod +x "$PKGROOT/usr/local/gx430t/scripts/"*.sh
chmod +x "$PKGROOT/usr/local/gx430t/install/"*.sh

ln -sf /usr/local/gx430t/bin/gx430tctl "$PKGROOT/usr/local/bin/gx430tctl"

# GX430T_PACKAGE_PAYLOAD_SANITIZE_V2_BEGIN
find "$PKGROOT" -depth -type d \( \
  -name DerivedData \
  -o -name DerivedDataDevice \
  -o -name build \
  -o -name .build \
  -o -name .swiftpm \
  -o -name xcuserdata \
\) -exec rm -rf {} +

find "$PKGROOT" -type f \( \
  -name '*.xcuserstate' \
  -o -name '*.xcuserdatad' \
\) -delete

if find "$PKGROOT" \
  \( \
    -path '*/DerivedData/*' \
    -o -path '*/DerivedDataDevice/*' \
    -o -path '*/.build/*' \
    -o -path '*/.swiftpm/*' \
    -o -path '*/xcuserdata/*' \
    -o -name '*.xcuserstate' \
  \) \
  -print \
  -quit \
  | grep -q .; then
  echo "GX430T_GENERATED_BUILD_STATE_IN_PACKAGE=true" >&2
  exit 1
fi
# GX430T_PACKAGE_PAYLOAD_SANITIZE_V2_END

pkgbuild \
  --root "$PKGROOT" \
  --identifier "$IDENTIFIER" \
  --version "$VERSION" \
  --scripts "$ROOT/installer/scripts" \
  --install-location / \
  "$PKG"

shasum -a 256 "$PKG" > "$PKG.sha256"
echo "GX430T_PKG_BUILD_DONE=true"
echo "PKG=$PKG"
echo "SHA256=$PKG.sha256"
