# GX430T Universal Upload Queue v0.3.2

Upload Queue is now available across the whole product.

## Native Mac app

- Quick Print
- Upload Queue
- Choose Excel / CSV
- Open Queue
- Refresh Queue
- Print Next
- Print All

## Mac menu bar

- Open GX430T
- Upload Queue
- Print Next Queue Label
- Print All Queued Labels
- Open Queue Browser
- Refresh Printer

## iPhone

The iPhone app exposes Queue through GX430TiPhoneRootWithQueueView.

- Set the Mac Print Host address
- Choose CSV/XLSX files
- Upload to /api/upload
- Refresh queue state
- Print next/all

For iPhone, use the Mac LAN address instead of 127.0.0.1, for example: http://192.168.1.20:9430

## Queue rules

- CSV and XLSX supported.
- Rows print in spreadsheet order.
- order, ordine, sequence, or priority can control order.
- quantity, qty, or qta expands one row into multiple labels.
