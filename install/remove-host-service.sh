#!/usr/bin/env bash
set -euo pipefail

PLIST="$HOME/Library/LaunchAgents/com.kaaffilm.gx430t.print-host.plist"
UID_VALUE="$(id -u)"

launchctl bootout "gui/$UID_VALUE/com.kaaffilm.gx430t.print-host" 2>/dev/null || true
rm -f "$PLIST"

echo "GX430T_HOST_SERVICE_REMOVED=true"
