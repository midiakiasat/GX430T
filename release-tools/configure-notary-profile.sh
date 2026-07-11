#!/usr/bin/env bash
set -euo pipefail

PROFILE="${GX430T_NOTARY_PROFILE:-GX430T-NOTARY}"
APPLE_ID="${GX430T_APPLE_ID:-}"
TEAM_ID="${GX430T_APPLE_TEAM_ID:-}"
APP_PASSWORD="${GX430T_APP_SPECIFIC_PASSWORD:-}"

if [[ -z "$APPLE_ID" ]]; then
  read -r -p "Apple ID: " APPLE_ID
fi

if [[ -z "$TEAM_ID" ]]; then
  read -r -p "Apple Team ID: " TEAM_ID
fi

if [[ -z "$APP_PASSWORD" ]]; then
  read -r -s -p "App-specific password: " APP_PASSWORD
  echo
fi

xcrun notarytool store-credentials "$PROFILE" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID" \
  --password "$APP_PASSWORD"

xcrun notarytool history \
  --keychain-profile "$PROFILE" \
  >/dev/null

echo "GX430T_NOTARY_PROFILE_CONFIGURED=true"
echo "GX430T_NOTARY_PROFILE=$PROFILE"
