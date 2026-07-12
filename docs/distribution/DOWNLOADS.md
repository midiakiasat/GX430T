# GX430T Downloads

## Official source

The only authoritative public project location is:

**GitHub repository**

`https://github.com/midiakiasat/GX430T`

**Latest release**

`https://github.com/midiakiasat/GX430T/releases/latest`

Do not distribute files copied from local build folders, chat attachments,
email attachments, shared drives, or unofficial mirrors.

## Files colleagues should receive

A complete published release should provide:

| File | Used by |
| --- | --- |
| `GX430T-Mac-Control-<version>.pkg` | Mac installation |
| `GX430T-Mac-Control-<version>.dmg` | Optional guided Mac distribution |
| `GX430T-iPhone-<version>.ipa` or managed TestFlight/App Store link | iPhone installation |
| `SHA256SUMS.txt` | File integrity verification |
| `GX430T-QUICKSTART.pdf` | Colleague instructions |
| `GX430T-WORK-PRESENTATION.pdf` | Brief workplace presentation |
| `RELEASE-MANIFEST.json` | Release identity and provenance |

## macOS support boundary

The host Mac is physically connected to the Zebra GX430t by USB.

Colleague Macs connect to the host Mac through the local network using the
GX430T application and the shared printer endpoint.

The Zebra printer itself is not required to have Wi-Fi, cloud access, or a
public internet address.

## Security rule

Never expose CUPS, IPP, the GX430T print host, pairing endpoints, or printer
management ports directly to the public internet.

Global distribution means the software and documentation are globally
available. It does not mean that a private workplace printer is globally
reachable.
