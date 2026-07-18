#!/usr/bin/env bash
set -euo pipefail

ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.."
  pwd
)"

PYTHON="$(
  command -v python3 ||
  true
)"

if [[ -z "$PYTHON" ]]; then
  echo "GX430T_HOST_PYTHON3_NOT_FOUND=true" >&2
  exit 69
fi

export GX430T_HOST_BIND="${
  GX430T_HOST_BIND:-0.0.0.0
}"

export GX430T_HOST_PORT="${
  GX430T_HOST_PORT:-43043
}"

export GX430T_PORT="$GX430T_HOST_PORT"

export GX430T_CLI="${
  GX430T_CLI:-/usr/local/bin/gx430tctl
}"

exec "$PYTHON" \
  "$ROOT/host-service/gx430t_host.py" \
  serve \
  --bind "$GX430T_HOST_BIND" \
  --port "$GX430T_HOST_PORT"
