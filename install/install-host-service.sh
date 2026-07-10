#!/usr/bin/env bash
set -euo pipefail

APP_SUPPORT="$HOME/Library/Application Support/GX430T"
LOG_DIR="$HOME/Library/Logs/GX430T"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
CONFIG="$APP_SUPPORT/host.json"
PLIST="$LAUNCH_AGENTS/com.kaaffilm.gx430t.print-host.plist"
UID_VALUE="$(id -u)"

mkdir -p "$APP_SUPPORT" "$LOG_DIR" "$LAUNCH_AGENTS"

if [[ ! -f "$CONFIG" ]]; then
  TOKEN="$(openssl rand -hex 32)"
  HOST_NAME="$(scutil --get ComputerName 2>/dev/null || hostname)"

  cat > "$CONFIG" <<JSON
{
  "schema": "gx430t.print_host_config.v1",
  "hostName": "$HOST_NAME",
  "port": 43043,
  "token": "$TOKEN",
  "protocol": 1
}
JSON

  chmod 600 "$CONFIG"
fi

cat > "$PLIST" <<EOF_PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.kaaffilm.gx430t.print-host</string>

  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/gx430t/host-service/run-host.sh</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>KeepAlive</key>
  <true/>

  <key>StandardOutPath</key>
  <string>$LOG_DIR/host.stdout.log</string>

  <key>StandardErrorPath</key>
  <string>$LOG_DIR/host.stderr.log</string>

  <key>ProcessType</key>
  <string>Interactive</string>
</dict>
</plist>
EOF_PLIST

launchctl bootout "gui/$UID_VALUE/com.kaaffilm.gx430t.print-host" 2>/dev/null || true
launchctl bootstrap "gui/$UID_VALUE" "$PLIST"
launchctl kickstart -k "gui/$UID_VALUE/com.kaaffilm.gx430t.print-host"

echo "GX430T_HOST_SERVICE_INSTALLED=true"
