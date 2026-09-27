# Phone preview over Wi-Fi (no install, no debugging)

Open the app in your phone's browser by scanning a QR code. Nothing is
installed, and developer options / wireless debugging can stay **off**
(banking apps refuse to run with them on). Installing the real APK over
wireless debugging is still there for major updates.

Requirements: the phone and the PC are on the **same Wi-Fi**. The first time,
Windows Firewall asks whether Dart may use private networks: click **Allow**.

## In Android Studio

Pick one from the run-configuration dropdown (they live in `.run/`):

| Configuration | What it does | When to use |
|---|---|---|
| **Phone preview (web)** | Builds the web release (~1 min), serves it on port 8081, prints a QR code in the Run console | Checking a finished change; loads fast on the phone |
| **Phone preview (web, live reload)** | Runs a debug web build on port 8080, QR printed first; after editing code press **Hot Restart** and the page on the phone reloads with the change | Working on UI and wanting to see it on the phone as you go (slower first load) |

Stop either with the red Stop button.

## From a terminal

```powershell
dart run tool/phone_preview.dart             # build + serve + QR
dart run tool/phone_preview.dart --no-build  # serve the last build again
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080   # live reload
dart run tool/phone_preview.dart --qr-only 8080                   # its QR
```

Add `--light` if your console has a light background (the QR is drawn for
dark consoles by default). If the QR's address doesn't load, the console lists
the PC's other network addresses to try.

## Good to know

- The browser version keeps its **own** progress (browser storage), separate
  from the installed app's.
- Vibration on answers doesn't happen in the browser; everything else is the
  same app.
- It's for previewing on your own network only - the server isn't meant to
  be exposed to the internet.
