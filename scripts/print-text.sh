#!/usr/bin/env bash
set -euo pipefail

VALUE="${1:-}"
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

if [[ -z "$VALUE" ]]; then
  echo "GX430T_TEXT_VALUE_REQUIRED=true" >&2
  exit 64
fi

if ! [[ "$COPIES" =~ ^[0-9]+$ ]] || (( COPIES < 1 || COPIES > 999 )); then
  echo "GX430T_INVALID_COPY_COUNT=true" >&2
  exit 64
fi

SAFE_VALUE="${VALUE//\\/\\\\}"
SAFE_VALUE="${SAFE_VALUE//^/\\^}"
SAFE_VALUE="${SAFE_VALUE//~/\\~}"

TMP="$(mktemp /tmp/gx430t-text.XXXXXX.zpl)"
trap 'rm -f "$TMP"' EXIT

cat > "$TMP" <<ZPL
^XA
^PW812
^LL600
^PR2
^MD20
^CI28
^FO60,120
^A0N,72,72
^FB692,5,10,C,0
^FD$SAFE_VALUE^FS
^PQ$COPIES
^XZ
ZPL

gx430t_require_printer_destination
"$LPR" -P "$PRINTER" -l "$TMP"

echo "GX430T_TEXT_PRINT_SENT=true"
