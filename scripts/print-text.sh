#!/usr/bin/env bash
set -euo pipefail

VALUE="${1:-}"
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
gx430t_submit_raw "$TMP"

echo "GX430T_TEXT_PRINT_SENT=true"
