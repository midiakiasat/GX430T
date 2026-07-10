# GX430T Print Host

The USB-connected work Mac can run the GX430T Print Host service.

Install and start:

```bash
gx430tctl host-install
````

Inspect:

```bash
gx430tctl host-status
gx430tctl host-info
```

The service listens on TCP port `43043`.

Endpoints:

```text
GET  /v1/health
GET  /v1/status
GET  /v1/info
POST /v1/print
```

Printing requires the bearer token generated during host installation.

Example:

```bash
curl \
  -H "Authorization: Bearer HOST_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"kind":"code128","value":"1234567890","copies":1}' \
  http://HOST_IP:43043/v1/print
```

Supported kinds:

```text
text
code128
code39
qr
```


## Pairing

A client pairs once using the six-digit code shown by:

```bash
gx430tctl host-info
````

Pairing request:

```bash
curl \
  -H "Content-Type: application/json" \
  -d '{"pairingCode":"123456","clientName":"Studio iPhone"}' \
  http://HOST_IP:43043/v1/pair
```

A successful request returns the bearer token to the client and immediately rotates the six-digit pairing code.

Rotate the code manually:

```bash
gx430tctl host-rotate-pairing
```

Print-host tokens must never be committed, published, displayed in release evidence, or shared outside authorized devices.
