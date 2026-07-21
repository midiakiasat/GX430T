# GX430T Colleague Quickstart

## Install on Mac
1. Open `GX430T-Share`.
2. Double-click `INSTALL-MAC.command`.
3. Enter the Mac password if requested.
4. Open `GX430T Mac Control`.

## Pair iPhone
1. Keep Mac and iPhone on the same network.
2. In the Mac menu-bar app, read the host, port, and pairing code.
3. On iPhone, enter:
   - Host: the Mac host/IP shown by the app
   - Port: 43043
   - Pairing code: current code shown by the Mac app
4. Pair once. The host token is preserved unless reset.

## Print
1. Upload CSV, TSV, XLSX, or ODS.
2. Choose format: Text, Code128, Code39, or QR.
3. Use Code128 for scanner-safe barcode labels.
4. Press Print Next or Print All.
5. Printing is intentionally one-by-one with cooldown for thermal quality.

## Hard rule
GX430T must print only to `GX430t`. Do not route this app to office printers.

## Current status
Version 0.3.3 build 33, commit a0c49667e88c6eab91c9e1c9fb9166ac45760da4.
Mac package is internal unsigned/unnotarized.
