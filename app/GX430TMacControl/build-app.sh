#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_DIR="$ROOT/app/GX430TMacControl/build/GX430T Mac Control.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RES="$CONTENTS/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RES"

swiftc "$ROOT/app/GX430TMacControl/Sources/GX430TMacControl/main.swift" -o "$MACOS/GX430TMacControl"

cp -f "$ROOT/app/GX430TMacControl/Resources/Info.plist" "$CONTENTS/Info.plist" 2>/dev/null || cat > "$CONTENTS/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>GX430T Mac Control</string>
<key>CFBundleDisplayName</key><string>GX430T Mac Control</string>
<key>CFBundleIdentifier</key><string>com.midiakiasat.gx430t.maccontrol</string>
<key>CFBundleVersion</key><string>0.2.9</string>
<key>CFBundleShortVersionString</key><string>0.2.9</string>
<key>CFBundleExecutable</key><string>GX430TMacControl</string>
<key>LSMinimumSystemVersion</key><string>10.13</string>
</dict></plist>
EOF

cp -f "$ROOT/app/GX430TMacControl/Resources/GX430TAppIcon.icns" "$RES/" 2>/dev/null || true
cp -f "$ROOT/branding/ZEBRAGX430TLOGO.svg" "$RES/" 2>/dev/null || true

echo "BUILT_APP=$APP_DIR"
