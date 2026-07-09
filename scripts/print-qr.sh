#!/usr/bin/env bash
set -euo pipefail

DATA="${1:-}"
COPIES="${2:-1}"
PRINTER="${GX430T_PRINTER:-GX430t}"
OUT="${GX430T_ZPL_OUT:-/tmp/gx430t-qr.zpl}"

if [[ -z "$DATA" ]]; then
  echo "usage: $0 <qr-value> [copies]" >&2
  exit 64
fi

cat > "$OUT" <<ZPL
^XA
^PW812
^LL600
^PR2
^MD20
^FO100,80
^BQN,2,8
^FDLA,$DATA^FS
^PQ$COPIES
^XZ
ZPL

lpr -P "$PRINTER" -l "$OUT"
echo "GX430T_QR_PRINT_SENT=true"
