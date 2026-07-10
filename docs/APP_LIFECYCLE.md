# GX430T Application Lifecycle

GX430T can launch automatically when the user signs in.

Enable:

```bash
gx430tctl app-autostart-on
````

Inspect:

```bash
gx430tctl app-autostart-status
```

Disable:

```bash
gx430tctl app-autostart-off
```

The USB-connected host Mac also exposes explicit Print Host lifecycle commands:

```bash
gx430tctl host-start
gx430tctl host-stop
gx430tctl host-restart
gx430tctl host-status
```

The application and Print Host use separate LaunchAgent boundaries.
