#!/usr/bin/env bash
set -euo pipefail

DATA="${1:-}"
COPIES="${2:-1}"
PRINTER="${GX430T_PRINTER:-GX430t}"
OUT="${GX430T_ZPL_OUT:-/tmp/gx430t-code128.zpl}"

if [[ -z "$DATA" ]]; then
  echo "usage: $0 <barcode-value> [copies]" >&2
  exit 64
fi

if ! [[ "$COPIES" =~ ^[0-9]+$ ]] || [[ "$COPIES" -lt 1 ]]; then
  echo "copies must be a positive integer" >&2
  exit 64
fi

cat > "$OUT" <<ZPL
^XA
^PW812
^LL600
^PR2
^MD20
^FO80,90
^BY4,3,230
^BCN,230,Y,N,N
^FD$DATA^FS
^PQ$COPIES
^XZ
ZPL

lpr -P "$PRINTER" -l "$OUT"
echo "GX430T_CODE128_PRINT_SENT=true"
echo "PRINTER=$PRINTER"
echo "COPIES=$COPIES"
echo "DATA=$DATA"
echo "ZPL=$OUT"
