#!/usr/bin/env bash
set -euo pipefail

echo "=== GX430T COLLEAGUE MAC INSTALL ==="

HOST_IP="${1:-192.168.0.55}"
CLIENT_PRINTER="${GX430T_CLIENT_PRINTER:-GX430t_shared}"
MODEL="${GX430T_MODEL:-drv:///sample.drv/zebra.ppd}"

echo "HOST_IP=$HOST_IP"
echo "CLIENT_PRINTER=$CLIENT_PRINTER"
echo "IPP=ipp://$HOST_IP/printers/GX430t"

sudo lpadmin -p "$CLIENT_PRINTER" -E -v "ipp://$HOST_IP/printers/GX430t" -m "$MODEL"

lpstat -p "$CLIENT_PRINTER" -l

cat > /tmp/gx430t-client-test.zpl <<'ZPL'
^XA
^PW812
^LL600
^PR2
^MD20
^FO80,90
^BY4,3,230
^BCN,230,Y,N,N
^FD1234567890^FS
^PQ1
^XZ
ZPL

lpr -P "$CLIENT_PRINTER" -l /tmp/gx430t-client-test.zpl

echo "GX430T_COLLEAGUE_CLIENT_INSTALL_DONE=true"
