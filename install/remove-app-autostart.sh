#!/usr/bin/env bash
set -euo pipefail

PLIST="$HOME/Library/LaunchAgents/com.kaaffilm.gx430t.mac-control.autostart.plist"
LABEL="com.kaaffilm.gx430t.mac-control.autostart"
UID_VALUE="$(id -u)"

launchctl bootout "gui/$UID_VALUE/$LABEL" 2>/dev/null || true
launchctl disable "gui/$UID_VALUE/$LABEL" 2>/dev/null || true
rm -f "$PLIST"

echo "GX430T_APP_AUTOSTART_REMOVED=true"
