# GX430T macOS signing and notarization

The public macOS distribution pipeline requires:

- Developer ID Application certificate
- Developer ID Installer certificate
- Apple notarization credentials stored in the macOS Keychain
- hardened runtime application signing
- signed installer package
- accepted Apple notarization submission
- stapled notarization ticket
- final SHA-256 digest

Audit readiness:

```bash
bash release-tools/audit-macos-distribution.sh
````

Configure notarization credentials:

```bash
GX430T_APPLE_ID="name@example.com" \
GX430T_APPLE_TEAM_ID="TEAMID" \
GX430T_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
bash release-tools/configure-notary-profile.sh
```

Build the signed and notarized package:

```bash
GX430T_VERSION=0.3.0 \
bash release-tools/build-signed-notarized-macos.sh
```

The final artifact is:

```text
release/GX430T-Mac-Control-<version>-notarized.pkg
```

A local Apple Development certificate is sufficient for direct development
testing but is not a replacement for Developer ID Application and Developer ID
Installer certificates used for public macOS distribution.
