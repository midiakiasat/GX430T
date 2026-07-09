#!/usr/bin/env bash
set -euo pipefail

PRINTER="${GX430T_PRINTER:-GX430t}"

sudo cupsctl --share-printers
sudo lpadmin -p "$PRINTER" -o printer-is-shared=true

HOST_IP="$(ipconfig getifaddr en1 || ipconfig getifaddr en0 || true)"

lpstat -p "$PRINTER" -l
echo "GX430T_HOST_SHARING_ENABLED=true"
echo "HOST_IP=$HOST_IP"
echo "IPP=ipp://$HOST_IP/printers/$PRINTER"
