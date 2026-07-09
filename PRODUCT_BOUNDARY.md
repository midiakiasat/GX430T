# GX430T Mac Control Product Boundary

## Product identity

GX430T Mac Control is a bounded macOS product for Zebra GX430t installation, operation, sharing, barcode creation, and diagnostic repair.

It exists because a working terminal path has already been proven:

```text
macOS USB discovery -> CUPS queue -> Zebra ZPL profile -> literal ZPL print -> scanner-readable label
```

The product turns that path into an installable, repeatable, supportable operator system.

## Governing sentence

GX430T Mac Control installs and operates a Zebra GX430t on macOS through bounded CUPS, IPP, and ZPL control surfaces.

## In-scope

GX430T Mac Control may own:

- macOS printer discovery
- local USB printer queue installation
- Zebra ZPL queue binding
- host Mac sharing enablement
- colleague client queue installation
- Code 128 label generation
- Code 39 label generation
- QR label generation
- scanner-safe label profiles
- print speed/darkness profile emission
- calibration command emission
- reset command emission
- CUPS status collection
- USB status collection
- IPP endpoint status collection
- diagnostic bundle generation
- uninstall and repair scripts
- native app surface
- CLI surface
- installer package
- release verification workflow

## Out-of-scope

GX430T Mac Control must not claim to own:

- Zebra firmware authority
- Zebra driver vendor status
- macOS printing subsystem authority
- scanner hardware configuration authority
- warehouse inventory truth
- enterprise asset custody truth
- package sovereignty
- hidden root access beyond explicit installer/helper operations

## Host mode boundary

Host mode applies only to the Mac physically connected to the Zebra GX430t.

Host mode may:

- discover the USB printer
- create or repair the `GX430t` queue
- test literal ZPL transport
- enable CUPS printer sharing
- expose `ipp://<host-ip>/printers/GX430t`
- print labels locally
- produce host diagnostics

Host mode may not:

- guarantee Wi-Fi reachability outside the local network
- bypass macOS firewall policy silently
- infer scanner readability without a physical scan check
- claim client installation success on machines it did not inspect

## Client mode boundary

Client mode applies to colleague Macs that do not have the USB Zebra attached.

Client mode may:

- create `GX430t_shared`
- bind it to the host IPP endpoint
- print ZPL through the host Mac
- run the same barcode generator against the shared queue
- produce client diagnostics

Client mode may not:

- discover the USB printer directly when it is not attached
- repair the host Mac queue remotely
- guarantee host availability when the host Mac sleeps, disconnects, or changes IP

## ZPL profile boundary

The product emits ZPL.

ZPL profiles must be explicit and testable:

- printer width
- label length
- print speed
- darkness
- origin
- barcode symbology
- module width
- ratio
- height
- human-readable text setting
- copy count

Scanner-safe defaults must prefer readability over visual compression.

## Diagnostic boundary

Diagnostics are evidence, not automatic truth.

A diagnostic bundle may include:

- `lpstat` output
- `lpinfo` output
- CUPS queue details
- USB profiler excerpt
- generated ZPL file
- print command used
- host IP
- IPP endpoint
- timestamp
- macOS version

A diagnostic bundle proves what was observed on that machine at that time. It does not prove all future printing will succeed.

## Release boundary

A release may claim:

- installer package exists
- CLI exists
- scripts exist
- verification workflow passed
- source tree is licensed Apache-2.0
- release artifact was produced

A release may not claim:

- universal macOS compatibility without tested matrix
- scanner readability for every scanner and label stock
- Zebra firmware support beyond ZPL emission
- network sharing success outside local network constraints

## Product maturity levels

```text
FOUNDATION_DECLARED
LOCAL_CLI_OPERATIONAL
HOST_CLIENT_OPERATIONAL
NATIVE_APP_OPERATIONAL
PKG_INSTALLER_OPERATIONAL
SIGNED_RELEASE_READY
UPDATER_OPERATIONAL
FIELD_SUPPORT_READY
```

Current target: `FOUNDATION_DECLARED` with working CLI/script substrate.
