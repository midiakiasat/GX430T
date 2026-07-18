#!/usr/bin/env bash
set -euo pipefail

ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.."
  pwd
)"

PYTHON="$(
  command -v python3 ||
  true
)"

if [[ -z "$PYTHON" ]]; then
  echo "GX430T_HOST_PYTHON3_NOT_FOUND=true" >&2
  exit 69
fi

APP_SUPPORT="$HOME/Library/Application Support/GX430T"
LOG_DIR="$HOME/Library/Logs/GX430T"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"

CONFIG="$APP_SUPPORT/host.json"
PLIST="$LAUNCH_AGENTS/com.kaaffilm.gx430t.print-host.plist"
LABEL="com.kaaffilm.gx430t.print-host"
UID_VALUE="$(id -u)"

mkdir -p \
  "$APP_SUPPORT" \
  "$LOG_DIR" \
  "$LAUNCH_AGENTS"

GX430T_HOST_PORT=43043 \
GX430T_PORT=43043 \
GX430T_CLI=/usr/local/bin/gx430tctl \
"$PYTHON" \
  "$ROOT/host-service/gx430t_host.py" \
  init-config \
  > "$APP_SUPPORT/host-install-result.json"

chmod 600 "$CONFIG"

cat > "$PLIST" <<EOF_PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>

  <key>ProgramArguments</key>
  <array>
    <string>$ROOT/host-service/run-host.sh</string>
  </array>

  <key>WorkingDirectory</key>
  <string>$ROOT</string>

  <key>EnvironmentVariables</key>
  <dict>
    <key>GX430T_HOST_BIND</key>
    <string>0.0.0.0</string>

    <key>GX430T_HOST_PORT</key>
    <string>43043</string>

    <key>GX430T_PORT</key>
    <string>43043</string>

    <key>GX430T_CLI</key>
    <string>/usr/local/bin/gx430tctl</string>
  </dict>

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

plutil -lint "$PLIST"

launchctl bootout \
  "gui/$UID_VALUE/$LABEL" \
  2>/dev/null ||
  true

launchctl bootstrap \
  "gui/$UID_VALUE" \
  "$PLIST"

launchctl enable \
  "gui/$UID_VALUE/$LABEL"

launchctl kickstart \
  -k \
  "gui/$UID_VALUE/$LABEL"

echo "GX430T_HOST_SERVICE_INSTALLED=true"
echo "GX430T_HOST_PORT=43043"
echo "GX430T_HOST_PROTOCOL=1"
echo "GX430T_HOST_URL=http://127.0.0.1:43043"

"$PYTHON" - "$CONFIG" <<'PY_CONFIG'
import json
import pathlib
import sys

config = json.loads(
    pathlib.Path(sys.argv[1]).read_text()
)

print(
    "GX430T_PAIRING_CODE="
    + str(config.get("pairingCode", ""))
)
PY_CONFIG

if [[ -f \
  /Library/LaunchDaemons/com.midiakiasat.gx430t.host.plist
]]; then
  echo "GX430T_LEGACY_SYSTEM_HOST_DETECTED=true"
  echo "GX430T_LEGACY_SYSTEM_HOST_REMOVAL_PENDING=true"
fi
