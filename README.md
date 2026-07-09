# GX430T Mac Control

**GX430T Mac Control** is a macOS control surface for installing, configuring, sharing, and printing scanner-safe labels on the Zebra GX430t.

It starts from a verified real-world baseline:

- macOS detects the printer over USB as `ZTC GX430t`.
- The command set is `ZPL`.
- The local CUPS printer queue is `GX430t`.
- Raw ZPL printing works through `lpr -P GX430t -l`.
- Scanner-safe Code 128 labels are produced by controlled ZPL profiles.
- A host Mac can share the USB printer to colleagues through IPP.

This repository is not a loose script dump. It is the product foundation for a real installable, upgradable macOS app and CLI.

## Product sentence

GX430T Mac Control installs, verifies, operates, shares, and repairs a Zebra GX430t on macOS without requiring operators to understand CUPS, IPP, USB printer URIs, or ZPL internals.

## Primary roles

| Surface | Role |
| --- | --- |
| macOS app | Native operator interface for printer setup, barcode creation, preview, and printing. |
| `gx430tctl` CLI | Power-user and automation interface for install, repair, print, share, and diagnose. |
| installer package | Bounded installable distribution surface for app, CLI, templates, and helper scripts. |
| ZPL profiles | Scanner-safe label generation profiles for Code 128, Code 39, and QR output. |
| host mode | USB-attached Mac shares the real printer through IPP. |
| client mode | Colleague Mac installs a shared printer pointing to the host Mac. |
| diagnostics | Evidence-producing checks for printer discovery, CUPS queue state, ZPL transport, and IPP sharing. |

## Non-role clauses

GX430T Mac Control does not claim to be a Zebra driver vendor, a firmware updater, a supply-chain authority, or an operating-system trust root.

It controls a bounded macOS install and print workflow using public macOS printing interfaces and ZPL output.

## Current operating baseline

Local USB printer:

```text
Printer queue: GX430t
USB URI: usb://Zebra%20Technologies/ZTC%20GX430t?serial=32J165201685
CUPS model: Zebra ZPL Label Printer
Working transport: lpr -P GX430t -l <file.zpl>
```

Known scanner-safe Code 128 profile:

```zpl
^XA
^PW812
^LL600
^PR2
^MD20
^FO80,90
^BY4,3,230
^BCN,230,Y,N,N
^FD1234567890^FS
^PQ1
^XZ
```

## Operator modes

### Host mode

Use host mode on the Mac physically connected to the Zebra by USB.

Host mode owns:

- USB printer discovery
- CUPS queue creation
- local ZPL test printing
- scanner-safe profile validation
- printer sharing
- host diagnostics
- IPP endpoint publication

Expected shared endpoint form:

```text
ipp://<HOST_MAC_IP>/printers/GX430t
```

### Client mode

Use client mode on colleague Macs.

Client mode owns:

- shared printer queue creation
- IPP endpoint validation
- ZPL print routing to host Mac
- local barcode app/CLI installation
- client diagnostics

Default client queue:

```text
GX430t_shared
```

## CLI contract

The CLI target is:

```bash
gx430tctl status
gx430tctl discover
gx430tctl install-local
gx430tctl install-client --host 192.168.0.158
gx430tctl print-code128 1234567890 --copies 3
gx430tctl print-code39 1234567890 --copies 3
gx430tctl print-qr "https://example.com" --copies 1
gx430tctl share-on
gx430tctl share-off
gx430tctl calibrate
gx430tctl repair
gx430tctl uninstall
gx430tctl diagnose
```

## App target

The native app target is a SwiftUI macOS application with:

- printer detection panel
- local install/repair panel
- client install panel
- host sharing panel
- barcode generator
- barcode type selector
- scanner-safe preset selector
- copy count field
- label size profile selector
- test print button
- diagnostic export
- update status panel

## Distribution target

The distribution target is:

- signed `.pkg` installer
- optional `.dmg` wrapper
- GitHub Releases distribution
- upgrade-safe postinstall
- uninstall script
- release verification workflow

## Repository law

This repository uses Apache License Version 2.0.

This repository must not overclaim beyond its bounded role: installable macOS Zebra GX430t control software.

## Fast start from source

Print a scanner-safe Code 128 test label from this repository after the printer is installed:

```bash
bash scripts/print-code128.sh 1234567890 1
```

Run baseline verification:

```bash
bash scripts/verify-gx430t-control.sh
```

Install or repair the local USB queue:

```bash
bash install/install-macos-cups.sh
```

Enable host sharing:

```bash
bash install/enable-host-sharing.sh
```

Install a colleague client queue:

```bash
bash install/install-client-shared-printer.sh 192.168.0.158
```

## Product maturity reading

Current repository status: product foundation.

This repo now establishes the installable product boundary, CLI contract, ZPL profiles, installer scripts, diagnostics, and release gate. Native SwiftUI implementation and packaged updater are downstream implementation work, not prerequisites for the product boundary to be clear.
