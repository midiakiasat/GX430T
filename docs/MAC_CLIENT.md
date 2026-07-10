# GX430T Mac Client

A Mac without the USB-connected printer can pair with the GX430T Print Host.

## Pair

On the host Mac:

```bash
gx430tctl host-info
````

On the client Mac:

```bash
gx430tctl client-pair http://HOST_IP:43043 PAIRING_CODE "Studio Mac"
```

The pairing token is stored privately at:

```text
~/Library/Application Support/GX430T/client.json
```

## Status

```bash
gx430tctl client-status
gx430tctl client-info
```

## Remote print

```bash
gx430tctl client-print text "Sample Room" 1
gx430tctl client-print code128 "1234567890" 1
gx430tctl client-print code39 "STYLE-100" 1
gx430tctl client-print qr "https://example.com" 1
```

## Remove pairing

```bash
gx430tctl client-remove
```

