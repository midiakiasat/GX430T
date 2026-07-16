#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="/usr/local/gx430t"
BIN_LINK="/usr/local/bin/gx430tctl"

echo "=== GX430T COLLEAGUE MAC INSTALL v0.2.9 ==="

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

sudo mkdir -p "$INSTALL_DIR"
sudo rsync -a --delete \
  --exclude ".git" \
  --exclude "release" \
  "$SRC/" "$INSTALL_DIR/"

sudo ln -sf "$INSTALL_DIR/bin/gx430tctl" "$BIN_LINK"

if [ -x "$INSTALL_DIR/install/install-macos-cups.sh" ]; then
  sudo "$INSTALL_DIR/install/install-macos-cups.sh" || true
fi

if [ -x "$INSTALL_DIR/install/install-host-service.sh" ]; then
  sudo "$INSTALL_DIR/install/install-host-service.sh" || true
fi

"$BIN_LINK" start-bg || true
open "http://127.0.0.1:9430" || true

echo "INSTALLED=$INSTALL_DIR"
echo "COMMAND=gx430tctl start"
echo "URL=http://127.0.0.1:9430"
echo "GX430T_COLLEAGUE_INSTALL_COMPLETE=true"
