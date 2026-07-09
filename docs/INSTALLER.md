# GX430T Mac Control Installer

Build the unsigned local development package:

```bash
bash installer/build-pkg.sh
````

Install the package:

```bash
sudo installer -pkg release/GX430T-Mac-Control-0.1.0.pkg -target /
```

After install:

```bash
gx430tctl verify
gx430tctl discover
gx430tctl status
```

The package installs:

```text
/usr/local/gx430t
/usr/local/bin/gx430tctl
```

This is the local unsigned package surface. Signing and notarization are later release-hardening work.
