#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${GX430T_VERSION:-0.1.0}"
IDENTIFIER="com.kaaffilm.gx430t.mac-control"
PKGROOT="$ROOT/installer/pkgroot"
OUTDIR="$ROOT/release"
PKG="$OUTDIR/GX430T-Mac-Control-$VERSION.pkg"

rm -rf "$PKGROOT/usr/local/gx430t"
mkdir -p "$PKGROOT/usr/local/gx430t" "$PKGROOT/usr/local/bin" "$OUTDIR"

rsync -a \
  --exclude ".git" \
  --exclude "installer/pkgroot" \
  --exclude "release" \
  "$ROOT/" "$PKGROOT/usr/local/gx430t/"

chmod +x "$PKGROOT/usr/local/gx430t/bin/gx430tctl"
chmod +x "$PKGROOT/usr/local/gx430t/scripts/"*.sh
chmod +x "$PKGROOT/usr/local/gx430t/install/"*.sh

ln -sf /usr/local/gx430t/bin/gx430tctl "$PKGROOT/usr/local/bin/gx430tctl"

pkgbuild \
  --root "$PKGROOT" \
  --scripts "$ROOT/installer/scripts" \
  --identifier "$IDENTIFIER" \
  --version "$VERSION" \
  --install-location / \
  "$PKG"

shasum -a 256 "$PKG" > "$PKG.sha256"

echo "GX430T_PKG_BUILD_DONE=true"
echo "PKG=$PKG"
echo "SHA256=$PKG.sha256"
