# GX430T iPhone App

The iPhone app is a secure client for the USB-connected work Mac.

Its operator flow is:

1. Pair with the work Mac using the six-digit code.
2. Type or paste label content.
3. Select Text, Code 128, Code 39, or QR.
4. Select copies.
5. Preview.
6. Print.

The iPhone never communicates directly with the USB printer. It submits authenticated jobs to the GX430T Print Host.

Generate the Xcode project:

```bash
bash ios/GX430TiPhone/generate-project.sh
````

Open it:

```bash id="uuimxw"
open ios/GX430TiPhone/GX430TiPhone.xcodeproj
```

The app requires iOS 17 or later.
