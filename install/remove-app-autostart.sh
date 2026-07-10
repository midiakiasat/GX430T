#!/usr/bin/env bash
set -euo pipefail

PLIST="$HOME/Library/LaunchAgents/com.kaaffilm.gx430t.mac-control.autostart.plist"
LABEL="com.kaaffilm.gx430t.mac-control.autostart"
DOMAIN="gui/$(id -u)"

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
launchctl bootout "$DOMAIN" "$PLIST" 2>/dev/null || true
launchctl disable "$DOMAIN/$LABEL" 2>/dev/null || true
rm -f "$PLIST"

echo "GX430T_APP_AUTOSTART_REMOVED=true"
