#!/usr/bin/env bash
set -euo pipefail

NOTARY_PROFILE="${GX430T_NOTARY_PROFILE:-GX430T-NOTARY}"

APP_IDENTITY_COUNT="$(
  security find-identity -v -p codesigning 2>/dev/null |
  grep -c 'Developer ID Application:' ||
  true
)"

INSTALLER_IDENTITY_COUNT="$(
  security find-identity -v -p basic 2>/dev/null |
  grep -c 'Developer ID Installer:' ||
  true
)"

if xcrun --find notarytool >/dev/null 2>&1; then
  NOTARYTOOL_AVAILABLE=true
else
  NOTARYTOOL_AVAILABLE=false
fi

if xcrun --find stapler >/dev/null 2>&1; then
  STAPLER_AVAILABLE=true
else
  STAPLER_AVAILABLE=false
fi

if [[ "$NOTARYTOOL_AVAILABLE" == "true" ]] &&
   xcrun notarytool history \
     --keychain-profile "$NOTARY_PROFILE" \
     >/dev/null 2>&1; then
  NOTARY_PROFILE_READY=true
else
  NOTARY_PROFILE_READY=false
fi

if [[ "$APP_IDENTITY_COUNT" -gt 0 ]] &&
   [[ "$INSTALLER_IDENTITY_COUNT" -gt 0 ]] &&
   [[ "$NOTARY_PROFILE_READY" == "true" ]] &&
   [[ "$STAPLER_AVAILABLE" == "true" ]]; then
  DISTRIBUTION_READY=true
else
  DISTRIBUTION_READY=false
fi

printf '%s\n' \
  "GX430T_DEVELOPER_ID_APPLICATION_COUNT=$APP_IDENTITY_COUNT" \
  "GX430T_DEVELOPER_ID_INSTALLER_COUNT=$INSTALLER_IDENTITY_COUNT" \
  "GX430T_NOTARYTOOL_AVAILABLE=$NOTARYTOOL_AVAILABLE" \
  "GX430T_NOTARY_PROFILE=$NOTARY_PROFILE" \
  "GX430T_NOTARY_PROFILE_READY=$NOTARY_PROFILE_READY" \
  "GX430T_STAPLER_AVAILABLE=$STAPLER_AVAILABLE" \
  "GX430T_MACOS_DISTRIBUTION_READY=$DISTRIBUTION_READY"
