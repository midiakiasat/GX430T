#!/usr/bin/env bash
set -euo pipefail

PLIST="/Library/LaunchDaemons/com.midiakiasat.gx430t.host.plist"
ROOT="/usr/local/gx430t"

sudo mkdir -p "$ROOT" "$HOME/.gx430t"

cat > /tmp/com.midiakiasat.gx430t.host.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.midiakiasat.gx430t.host</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/python3</string>
    <string>$ROOT/host-service/gx430t_host.py</string>
    <string>serve</string>
    <string>--port</string>
    <string>9430</string>
  </array>
  <key>WorkingDirectory</key><string>$ROOT</string>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/var/log/gx430t-host.log</string>
  <key>StandardErrorPath</key><string>/var/log/gx430t-host.err</string>
</dict>
</plist>
EOF

sudo cp /tmp/com.midiakiasat.gx430t.host.plist "$PLIST"
sudo chown root:wheel "$PLIST"
sudo chmod 644 "$PLIST"
sudo launchctl bootout system "$PLIST" >/dev/null 2>&1 || true
sudo launchctl bootstrap system "$PLIST" || true
sudo launchctl kickstart -k system/com.midiakiasat.gx430t.host || true

echo "GX430T_HOST_SERVICE_INSTALLED=true"
echo "URL=http://127.0.0.1:9430"
