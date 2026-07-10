#!/usr/bin/env bash
set -euo pipefail

APP="/Applications/GX430T Mac Control.app"
EXECUTABLE="$APP/Contents/MacOS/GX430TMacControl"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
PLIST="$LAUNCH_AGENTS/com.kaaffilm.gx430t.mac-control.autostart.plist"
LABEL="com.kaaffilm.gx430t.mac-control.autostart"
DOMAIN="gui/$(id -u)"

test -d "$APP"
test -x "$EXECUTABLE"

mkdir -p "$LAUNCH_AGENTS"

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
launchctl bootout "$DOMAIN" "$PLIST" 2>/dev/null || true
rm -f "$PLIST"

cat > "$PLIST" <<EOF_PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>

  <key>ProgramArguments</key>
  <array>
    <string>$EXECUTABLE</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>KeepAlive</key>
  <false/>

  <key>ProcessType</key>
  <string>Interactive</string>

  <key>LimitLoadToSessionType</key>
  <string>Aqua</string>

  <key>StandardOutPath</key>
  <string>$HOME/Library/Logs/GX430T/app-autostart.stdout.log</string>

  <key>StandardErrorPath</key>
  <string>$HOME/Library/Logs/GX430T/app-autostart.stderr.log</string>
</dict>
</plist>
EOF_PLIST

mkdir -p "$HOME/Library/Logs/GX430T"
chmod 600 "$PLIST"
plutil -lint "$PLIST"

launchctl enable "$DOMAIN/$LABEL" 2>/dev/null || true
launchctl bootstrap "$DOMAIN" "$PLIST"

echo "GX430T_APP_AUTOSTART_INSTALLED=true"
echo "GX430T_APP_AUTOSTART_PLIST=$PLIST"
