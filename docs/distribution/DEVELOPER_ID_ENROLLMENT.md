# GX430T Developer ID enrollment

## Local certificate request

The Apple certificate signing request is stored locally at:

`/Users/midiakiasat/Desktop/GX430T-Apple-Distribution/GX430T-Developer-ID.certSigningRequest`

CSR SHA-256:

`ab185dc94ce3566dc224578a14916f962a1c163561d9016fc5371ca658908965`

The matching RSA private key was imported into the macOS login keychain by the
successful `security import` operation. The temporary private-key file was
then securely removed.

The private key will not appear as a usable signing identity until Apple issues
a matching certificate and that certificate is installed in the same keychain.

## Required Apple certificates

Create these two certificates in the Apple Developer portal:

1. **Developer ID Application**
2. **Developer ID Installer**

Upload the same CSR for both requests.

After Apple issues each certificate:

1. Download the `.cer` file.
2. Open the file to import it into Keychain Access.
3. Confirm the certificate expands to show its matching private key.
4. Keep the certificate and private key in the login keychain.

## Required verification

After both certificates are installed:

```bash
security find-identity -v -p codesigning
security find-certificate -a -c "Developer ID Installer:"
```

The expected authorities are:

- `Developer ID Application: ...`
- `Developer ID Installer: ...`

## Apple notarization profile

After the certificates are installed, configure the repository notarization
profile:

```bash
cd /Users/midiakiasat/Downloads/Apps/midiakiasat/GX430T
bash release-tools/configure-notary-profile.sh
```

Then verify it:

```bash
xcrun notarytool history --keychain-profile GX430T_NOTARY
```

## Security boundary

Never commit or publish:

- private keys;
- certificate passwords;
- Apple ID app-specific passwords;
- App Store Connect API private keys;
- provisioning profiles;
- notarization credentials;
- exported keychain archives.

Production publication remains prohibited until Developer ID Application,
Developer ID Installer, and the notarization profile all pass verification.
