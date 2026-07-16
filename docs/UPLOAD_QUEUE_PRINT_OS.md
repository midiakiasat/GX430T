# GX430T Upload Queue Print OS v0.2.9

## What it does

GX430T Mac Control can now accept an Excel `.xlsx` or CSV file, map barcode/product columns automatically, expand quantities into individual labels, queue labels in file order, and print them in order to the GX430T.

## Start

```bash
gx430tctl start
````

Then open:

```text
http://127.0.0.1:9430
```

## Upload format

Supported columns include:

* `barcode`
* `sku`
* `style code`
* `item code`
* `codice`
* `ean`
* `description`
* `brand`
* `quantity`
* `qty`
* `qta`

If no exact barcode column exists, the first non-empty column is used.

## Print order

Rows are queued in file order. If the file includes `order`, `ordine`, `sequence`, or `priority`, that column controls ordering.

## Commands

```bash
gx430tctl start
gx430tctl upload products.xlsx
gx430tctl status
gx430tctl print-next
gx430tctl print-all
gx430tctl clear
gx430tctl stop
```

## Printer selection

Set a printer explicitly:

```bash
export GX430T_PRINTER="GX430T"
```

Otherwise the host searches installed CUPS printers for `GX430T` or `Zebra`.
