# GX430T Unified Deployment

GX430T is one product with two automatic operating roles.

## USB Host Mac

The work iMac is physically connected to the Zebra GX430t by USB.

It runs:

- the native GX430T application
- the GX430T Print Host service
- the local CUPS queue
- authenticated pairing
- network print submission
- bounded job history

## Network Client

A private Mac, colleague Mac, or iPhone does not require direct USB access.

It runs the same GX430T product and:

- pairs once with the USB Host Mac
- stores its credential privately
- reads remote printer status
- submits authenticated print jobs
- displays bounded job results

## Automatic role selection

The application uses this order:

1. Direct USB queue when available.
2. Paired Print Host when direct USB is unavailable.
3. Pairing interface when neither transport is available.

A successful API response proves submission to the host print queue. It does not independently prove that paper physically exited the printer.
