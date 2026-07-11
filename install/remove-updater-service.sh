#!/usr/bin/env bash
set -euo pipefail

LABEL="com.kaaffilm.gx430t.updater"
DOMAIN="gui/$(id -u)"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
rm -f "$PLIST"

echo "GX430T_UPDATER_SERVICE_REMOVED=true"
