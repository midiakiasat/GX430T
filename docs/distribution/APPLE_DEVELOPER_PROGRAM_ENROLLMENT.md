# Apple Developer Program enrollment authority

## Current blocker

The Apple Certificates, Identifiers & Profiles portal reports:

> Access Unavailable

The signed-in Apple Account is not currently authorized as either:

- an enrolled Apple Developer Program account holder; or
- a member of an organization enrolled in the Apple Developer Program.

This prevents issuance of:

- Developer ID Application certificates;
- Developer ID Installer certificates;
- notarization credentials suitable for public macOS distribution.

The existing Apple Development identity can sign registered-device development
builds. It does not authorize global macOS distribution.

## Required action

Use one of these authority paths:

1. Enroll the Apple Account in the Apple Developer Program.
2. Ask an enrolled organization Account Holder or Admin to invite the Apple
   Account to its developer team with certificate access.

After enrollment or team access becomes active:

1. Open Certificates, Identifiers & Profiles.
2. Create a Developer ID Application certificate using the GX430T CSR.
3. Create a Developer ID Installer certificate using the same GX430T CSR.
4. Download and import both issued certificates.
5. Configure the `GX430T_NOTARY` notarytool keychain profile.
6. Run the GX430T production signing and notarization pipeline.
7. Keep the production candidate draft unpublished until clean-machine install,
   pairing, and physical-print acceptance pass.

## Preserved boundary

The public workplace presentation pack remains valid and downloadable.

The macOS production package remains unauthorized for public release.

The physical printer, CUPS queue, print host, and pairing service remain private
to the approved workplace network.
