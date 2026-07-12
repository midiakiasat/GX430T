# GX430T Production Distribution Authority

## Current status

- Production distribution ready: **NO**
- Source commit: `14b929460dc73765e08c4f47e7cb19ce937b7560`
- Public workplace presentation: `https://github.com/midiakiasat/GX430T/releases/tag/v0.2.8-work1`
- Production candidate: `https://github.com/midiakiasat/GX430T/releases/tag/untagged-37165fe616fef360b6b1`

## Authority checks

| Result | Authority |
| --- | --- |
| MISSING | Developer ID Application certificate |
| MISSING | Developer ID Installer certificate |
| MISSING | Apple notarytool keychain profile |
| PASS | Apple Development certificate |
| PASS | Signing and notarization pipeline source |
| PASS | Production package payload verification |
| PASS | Production package checksum verification |
| PASS | Public workplace presentation release |
| PASS | Production candidate publication boundary |

## Required closure

- Obtain or configure: `developer_id_application_present`
- Obtain or configure: `developer_id_installer_present`
- Obtain or configure: `notary_profile_present`

## Publication boundary

The public workplace presentation pack is downloadable and verified.
The production macOS installer must remain unpublished until it is signed
with Developer ID identities, notarized by Apple, stapled, audited,
installed on a clean colleague Mac, paired with the approved print host,
and accepted through a physical label print.

The iPhone development build is verified on the registered device but is
not a globally distributable IPA or App Store release.
