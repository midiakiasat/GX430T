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
test -x bin/gx430tctl
test -x installer/build-pkg.sh
test -x installer/scripts/postinstall
grep -q "print-code128" bin/gx430tctl
echo "GX430T_CONTROL_VERIFY_PASS=true"

test -x scripts/print-text.sh
grep -q "print-text" bin/gx430tctl

test -x host-service/gx430t_host.py
test -x host-service/run-host.sh
test -x install/install-host-service.sh
test -x install/remove-host-service.sh
grep -q "host-install" bin/gx430tctl
grep -q "/v1/print" host-service/gx430t_host.py
