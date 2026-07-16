# GX430T Upload Queue v0.3.0

The main product remains the native GX430T Mac Control app.

The Excel/CSV queue is only a secondary batch-print tool. It must not replace the native app surface.

Start secondary queue:

```bash
gx430tctl start
````

Open:

```text
http://127.0.0.1:9430
```

Accepted columns include barcode, sku, style code, item code, codice, EAN, quantity, qty, qta, description, brand, order, ordine, sequence.

Quantity expands one spreadsheet row into the requested number of queue labels.
