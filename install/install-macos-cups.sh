#!/usr/bin/env bash
set -euo pipefail

PRINTER="${GX430T_PRINTER:-GX430t}"
URI="${GX430T_URI:-usb://Zebra%20Technologies/ZTC%20GX430t?serial=32J165201685}"
MODEL="${GX430T_MODEL:-drv:///sample.drv/zebra.ppd}"

sudo lpadmin -p "$PRINTER" -E -v "$URI" -m "$MODEL"
sudo lpoptions -d "$PRINTER"

lpstat -p "$PRINTER" -l
echo "GX430T_LOCAL_CUPS_INSTALL_DONE=true"
