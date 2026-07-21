# GX430T Work Presentation — Current Version

## One sentence
GX430T is a dedicated Zebra GX430t barcode-printing system for Mac and iPhone: upload a sheet, choose the barcode format, pair, and print safely.

## Current product authority
- Version: 0.3.3
- Build: 33
- Commit: a0c49667e88c6eab91c9e1c9fb9166ac45760da4
- Destination: GX430t only
- System default printer: not used by the app
- Supported queue inputs: CSV, TSV, XLSX, ODS
- Queue formats: Text, Code128, Code39, QR
- Default queue format: Code128
- Queue delivery: strict one-by-one
- Thermal cooldown: 4 seconds
- Raw IPP delivery: direct to GX430t, no double CUPS filtering

## What changed from the old presentation
The old story was “Mac controls GX430t.”
The current product is a complete queue system:
1. Mac menu-bar app controls host, pairing, queue, and print actions.
2. iPhone app pairs to the Mac host and uses the same format selector.
3. Queue printing no longer blasts labels too fast.
4. Every print route is pinned to GX430t.
5. Wrong-printer routing is blocked before print submission.
6. ZPL text dumping is blocked by raw delivery.
7. Colleague installation is packaged as one internal kit.

## User workflow
1. Install Mac package.
2. Open GX430T Mac Control.
3. Confirm printer status is ONLINE.
4. Copy pairing code.
5. Pair iPhone using host address, port 43043, and pairing code.
6. Upload sheet.
7. Select format: Text, Code128, Code39, or QR.
8. Print Next or Print All.
9. Labels print one-by-one for scanner readability.

## Operational status
- Mac app: required
- Mac menu bar: required
- Host service: required
- iPhone app: supported through developer/internal install
- Physical printer: GX430t only
- Current public blockers: Mac package not Developer ID signed, not notarized, iPhone public distribution not ready.
