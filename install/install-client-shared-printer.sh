#!/usr/bin/env bash
set -euo pipefail

HOST_IP="${1:-}"
CLIENT_PRINTER="${GX430T_CLIENT_PRINTER:-GX430t_shared}"
MODEL="${GX430T_MODEL:-drv:///sample.drv/zebra.ppd}"

if [[ -z "$HOST_IP" ]]; then
  echo "usage: $0 <host-ip>" >&2
  exit 64
fi

sudo lpadmin -p "$CLIENT_PRINTER" -E -v "ipp://$HOST_IP/printers/GX430t" -m "$MODEL"

lpstat -p "$CLIENT_PRINTER" -l
echo "GX430T_CLIENT_SHARED_INSTALL_DONE=true"
