# GX430T Native macOS App

`GX430T Mac Control.app` is a native SwiftUI control surface for the installed `gx430tctl` command dispatcher.

Build locally:

```bash
bash app/GX430TMacControl/build-app.sh
open "app/GX430TMacControl/build/GX430T Mac Control.app"
````

The app expects:

```text
/usr/local/bin/gx430tctl
```

The app does not replace the package or CLI boundary. It is a native operator surface over the verified command dispatcher.
