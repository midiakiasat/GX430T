#!/usr/bin/env bash
set -euo pipefail

ROOT="/usr/local/gx430t"
UPDATER="$ROOT/updater/gx430t_updater.py"
LOG_DIR="$HOME/Library/Logs/GX430T"

mkdir -p "$LOG_DIR"

if [[ ! -x "$UPDATER" ]]; then
  echo "GX430T_UPDATER_NOT_INSTALLED=true"
  exit 1
fi

set +e
"$UPDATER" check \
  >> "$LOG_DIR/updater.log" \
  2>&1
STATUS=$?
set -e

if [[ "$STATUS" -eq 0 ]] || [[ "$STATUS" -eq 10 ]]; then
  exit 0
fi

exit "$STATUS"
