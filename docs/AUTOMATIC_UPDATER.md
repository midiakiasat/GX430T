# GX430T automatic updater

GX430T includes a release updater for macOS packages published through GitHub
Releases.

The updater:

- reads the latest non-draft, non-prerelease GitHub release;
- compares semantic versions with the installed application;
- downloads the package and its SHA-256 record;
- verifies the checksum;
- verifies the GitHub asset digest when available;
- inspects the package signature;
- installs only after explicit authorization;
- stores no GitHub credentials;
- checks automatically every six hours through a user LaunchAgent.

Commands:

```bash
gx430t-update check
gx430t-update download
gx430t-update install
gx430t-update state
gx430t-update clear
````

Enable background update checks:

```bash
bash /usr/local/gx430t/install/install-updater-service.sh
```

Remove background update checks:

```bash
bash /usr/local/gx430t/install/remove-updater-service.sh
```

Automatic checks never silently install a package. Installation requires an
explicit user action and administrator authorization.

Public production updates must use the signed and notarized package pipeline.
