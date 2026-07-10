#!/usr/bin/env bash
set -euo pipefail

APP="/Applications/GX430T Mac Control.app"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
PLIST="$LAUNCH_AGENTS/com.kaaffilm.gx430t.mac-control.autostart.plist"
LABEL="com.kaaffilm.gx430t.mac-control.autostart"
UID_VALUE="$(id -u)"

test -d "$APP"
test -x "$APP/Contents/MacOS/GX430TMacControl"

mkdir -p "$LAUNCH_AGENTS"

cat > "$PLIST" <<EOF_PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>

  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/open</string>
    <string>-a</string>
    <string>GX430T Mac Control</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>ProcessType</key>
  <string>Interactive</string>

  <key>LimitLoadToSessionType</key>
  <string>Aqua</string>
</dict>
</plist>
EOF_PLIST

plutil -lint "$PLIST"

launchctl bootout "gui/$UID_VALUE/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$UID_VALUE" "$PLIST"
launchctl enable "gui/$UID_VALUE/$LABEL"
launchctl kickstart -k "gui/$UID_VALUE/$LABEL" 2>/dev/null || true

echo "GX430T_APP_AUTOSTART_INSTALLED=true"
echo "GX430T_APP_AUTOSTART_PLIST=$PLIST"
