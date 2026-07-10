# GX430T macOS Installer

Build the local package:

```bash
bash installer/build-pkg.sh
````

Install:

```bash
sudo installer -pkg release/GX430T-Mac-Control-0.1.0.pkg -target /
```

The package installs:

```text
/usr/local/gx430t
/usr/local/bin/gx430tctl
/Applications/GX430T Mac Control.app
```

Verify:

```bash
gx430tctl verify
gx430tctl discover
gx430tctl status
open "/Applications/GX430T Mac Control.app"
```

This is the local unsigned package surface. Signing and notarization are later release-hardening work.
