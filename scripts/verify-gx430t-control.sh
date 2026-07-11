#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

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

grep -q '"/v1/pair"' host-service/gx430t_host.py
grep -q "host-pairing-code" bin/gx430tctl
grep -q "host-rotate-pairing" bin/gx430tctl

test -x client/gx430t_client.py
grep -q "client-pair" bin/gx430tctl
grep -q "client-print" bin/gx430tctl
grep -q "GX430T_REMOTE_PRINT_ACCEPTED" client/gx430t_client.py

test -f branding/ZEBRAGX430TLOGO.svg
test -f app/GX430TMacControl/Resources/ZEBRAGX430TLOGO.svg
test -f ios/GX430TiPhone/Resources/ZEBRAGX430TLOGO.svg
grep -q '<svg' branding/ZEBRAGX430TLOGO.svg

test -x install/install-app-autostart.sh
test -x install/remove-app-autostart.sh
grep -q "app-autostart-on" bin/gx430tctl
grep -q "host-restart" bin/gx430tctl
test -f docs/APP_LIFECYCLE.md

grep -q '"/v1/jobs"' host-service/gx430t_host.py
grep -q '"/v1/jobs/summary"' host-service/gx430t_host.py
grep -q "client-jobs" bin/gx430tctl
grep -q "client-job-summary" bin/gx430tctl
grep -q "GX430T_REMOTE_JOBS_READ" client/gx430t_client.py
test -f docs/JOB_HISTORY.md

test -f docs/UNIFIED_DEPLOYMENT.md
grep -q "physicalDeliveryVerified" host-service/gx430t_host.py
grep -q "SUBMITTED_TO_CUPS" host-service/gx430t_host.py

test -x "$ROOT/release-tools/audit-macos-distribution.sh"
test -x "$ROOT/release-tools/configure-notary-profile.sh"
test -x "$ROOT/release-tools/build-signed-notarized-macos.sh"
test -f "$ROOT/docs/MACOS_SIGNING_NOTARIZATION.md"

test -x "$ROOT/updater/gx430t_updater.py"
test -x "$ROOT/updater/run-update-check.sh"
test -x "$ROOT/bin/gx430t-update"
test -x "$ROOT/install/install-updater-service.sh"
test -x "$ROOT/install/remove-updater-service.sh"
test -f "$ROOT/docs/AUTOMATIC_UPDATER.md"
python3 -m py_compile "$ROOT/updater/gx430t_updater.py"
bash -n "$ROOT/updater/run-update-check.sh"
bash -n "$ROOT/bin/gx430t-update"
bash -n "$ROOT/install/install-updater-service.sh"
bash -n "$ROOT/install/remove-updater-service.sh"
