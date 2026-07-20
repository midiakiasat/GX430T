#!/usr/bin/env bash
set -euo pipefail

DATA="${1:-}"
COPIES="${2:-1}"
PRINTER="GX430t"

LPSTAT="${GX430T_LPSTAT:-/usr/bin/lpstat}"
LP="${GX430T_LP:-/usr/bin/lp}"
PYTHON="${GX430T_PYTHON:-/usr/bin/python3}"
GX430T_DEVICE_URI=""

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

  if printf '%s\n' "$device_uri" |
    grep -Eiq '^dnssd://'
  then
    echo "GX430T_DNSSD_RAW_ROUTE_BLOCKED=true" >&2
    exit 69
  fi

  GX430T_DEVICE_URI="$device_uri"
}

gx430t_submit_raw() {
  local source_path="$1"
  local remote_server=""

  if printf '%s\n' "$GX430T_DEVICE_URI" |
    grep -Eiq '^ipps?://'
  then
    remote_server="$(
      "$PYTHON" - "$GX430T_DEVICE_URI" <<'PY_URI'
import sys
import urllib.parse

parsed = urllib.parse.urlsplit(sys.argv[1])
host = parsed.hostname or ""
port = parsed.port or 631

if ":" in host and not host.startswith("["):
    host = f"[{host}]"

print(f"{host}:{port}")
PY_URI
    )"

    "$LP"       -h "$remote_server"       -d "$PRINTER"       -o raw       "$source_path"
  else
    "$LP"       -d "$PRINTER"       -o raw       "$source_path"
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
gx430t_submit_raw "$OUT"
echo "GX430T_CODE128_PRINT_SENT=true"
