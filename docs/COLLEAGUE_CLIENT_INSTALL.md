# GX430T Colleague Client Install

Host Mac IP:

```text
192.168.0.55
```

Install command on colleague Mac:

```bash
curl -L https://raw.githubusercontent.com/midiakiasat/GX430T/main/client-kit/install-colleague-mac.sh -o /tmp/install-gx430t-client.sh
chmod +x /tmp/install-gx430t-client.sh
bash /tmp/install-gx430t-client.sh 192.168.0.55
```

Client queue:

```text
GX430t_shared
```

Client IPP endpoint:

```text
ipp://192.168.0.55/printers/GX430t
```

The host Mac must stay awake, connected to the same local network, and physically connected to the Zebra GX430t by USB.
