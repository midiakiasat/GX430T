#!/usr/bin/env bash
set -euo pipefail

LABEL="com.kaaffilm.gx430t.updater"
DOMAIN="gui/$(id -u)"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG_DIR="$HOME/Library/Logs/GX430T"
PROGRAM="/usr/local/gx430t/updater/run-update-check.sh"

test -x "$PROGRAM"

mkdir -p \
  "$HOME/Library/LaunchAgents" \
  "$LOG_DIR"

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC
  "-//Apple//DTD PLIST 1.0//EN"
  "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>

  <key>ProgramArguments</key>
  <array>
    <string>$PROGRAM</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>StartInterval</key>
  <integer>21600</integer>

  <key>ProcessType</key>
  <string>Background</string>

  <key>StandardOutPath</key>
  <string>$LOG_DIR/updater-launchagent.stdout.log</string>

  <key>StandardErrorPath</key>
  <string>$LOG_DIR/updater-launchagent.stderr.log</string>
</dict>
</plist>
PLIST

plutil -lint "$PLIST"

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
launchctl bootstrap "$DOMAIN" "$PLIST"
launchctl enable "$DOMAIN/$LABEL"
launchctl kickstart -k "$DOMAIN/$LABEL"

echo "GX430T_UPDATER_SERVICE_INSTALLED=true"
echo "GX430T_UPDATER_SERVICE_PLIST=$PLIST"
