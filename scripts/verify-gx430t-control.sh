#!/usr/bin/env bash
set -euo pipefail

test -f LICENSE
test -f README.md
test -x scripts/print-code128.sh
test -x scripts/print-code39.sh
test -x scripts/print-qr.sh
test -x install/install-macos-cups.sh
test -x install/enable-host-sharing.sh
test -x install/install-client-shared-printer.sh
grep -q "\\^BCN" scripts/print-code128.sh
grep -q "\\^B3N" scripts/print-code39.sh
grep -q "\\^BQN" scripts/print-qr.sh
grep -q "printer-is-shared=true" install/enable-host-sharing.sh
grep -q "GX430t_shared" install/install-client-shared-printer.sh
echo "GX430T_CONTROL_VERIFY_PASS=true"
