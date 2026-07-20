#!/usr/bin/env bash
set -euo pipefail

DATA="${1:-}"
COPIES="${2:-1}"
PRINTER="GX430t"

LPSTAT="${GX430T_LPSTAT:-/usr/bin/lpstat}"
LPR="${GX430T_LPR:-/usr/bin/lpr}"

gx430t_require_printer_destination() {
  local device_uri
  local printer_status

  device_uri="$(
    "$LPSTAT" -v "$PRINTER" 2>/dev/null |
    sed -n "s/^device for $PRINTER: //p" |
    head -1
  )"

  printer_status="$(
    "$LPSTAT" -p "$PRINTER" -l 2>&1 ||
    true
  )"

  if [[ -z "$device_uri" ]]; then
    echo "GX430T_DESTINATION_NOT_CONFIGURED=true" >&2
    exit 69
  fi

  if ! printf '%s\n' "$device_uri" |
    grep -Eiq 'gx430t|zebra|ztc|/printers/gx430t'
  then
    echo "GX430T_WRONG_PRINTER_ROUTING_BLOCKED=true" >&2
    echo "GX430T_REJECTED_DESTINATION=$device_uri" >&2
    exit 69
  fi

  if printf '%s\n' "$printer_status" |
    grep -Eiq 'offline|disabled|not accepting'
  then
    echo "GX430T_PRINTER_UNAVAILABLE=true" >&2
    printf '%s\n' "$printer_status" >&2
    exit 69
  fi
}
OUT="${GX430T_ZPL_OUT:-/tmp/gx430t-code128.zpl}"

if [[ -z "$DATA" ]]; then
  echo "usage: $0 <barcode-value> [copies]" >&2
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

gx430t_require_printer_destination
"$LPR" -P "$PRINTER" -l "$OUT"
echo "GX430T_CODE128_PRINT_SENT=true"
