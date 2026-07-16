# GX430T Upload Queue v0.3.1

The upload queue is now available from inside the native GX430T Mac Control app.

Main app stays native and professional:

- Quick Print remains the first/default surface.
- Upload Queue is available in the left sidebar.
- Operator can choose Excel `.xlsx` or CSV `.csv`.
- Queue preserves order.
- Quantity expands one spreadsheet row into multiple labels.
- Buttons inside the native app: Choose Excel / CSV, Open Queue, Refresh Queue, Print Next, Print All.

Supported columns include:

- barcode
- sku
- style code
- item code
- codice
- EAN
- quantity / qty / qta
- description / brand
- order / ordine / sequence

CLI remains available:

```bash
gx430tctl start
gx430tctl upload file.xlsx
gx430tctl upload file.csv
gx430tctl print-next
gx430tctl print-all
````

