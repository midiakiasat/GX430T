#!/usr/bin/env bash
set -euo pipefail

PRINTER="GX430t"
MODEL="${GX430T_MODEL:-drv:///sample.drv/zebra.ppd}"
KNOWN_URI="usb://Zebra%20Technologies/ZTC%20GX430t?serial=32J165201685"

echo "=== GX430T LOCAL CUPS INSTALL ==="

USB_URI="$(lpinfo -v 2>/dev/null | awk '/usb:.*Zebra|usb:.*ZTC|usb:.*GX430/ {print $2; exit}' || true)"

if [[ -z "$USB_URI" ]]; then
  if system_profiler SPUSBDataType 2>/dev/null | grep -qi "ZTC GX430t\|GX430t\|Zebra"; then
    USB_URI="$KNOWN_URI"
  fi
fi

if [[ -z "$USB_URI" ]]; then
  echo "GX430T_USB_NOT_DISCOVERED=true" >&2
  echo "CONNECT_ZEBRA_GX430T_USB_AND_POWER_ON=true" >&2
  echo "THEN_RUN=gx430tctl install-local" >&2
  exit 66
fi

echo "GX430T_USB_URI=$USB_URI"

sudo lpadmin -p "$PRINTER" -E -v "$USB_URI" -m "$MODEL"
echo "GX430T_SYSTEM_DEFAULT_PRINTER_UNCHANGED=true"

lpstat -p "$PRINTER" -l
echo "GX430T_LOCAL_CUPS_INSTALL_DONE=true"
