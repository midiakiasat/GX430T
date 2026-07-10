#!/usr/bin/env bash
set -euo pipefail

VALUE="${1:-}"
COPIES="${2:-1}"
PRINTER="${GX430T_PRINTER:-GX430t}"

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

lpr -P "$PRINTER" -l "$TMP"

echo "GX430T_TEXT_PRINT_SENT=true"
