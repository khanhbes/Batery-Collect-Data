# EV Trip Logger

App Flutter thu thap telemetry EV theo tung giay, xuat CSV va chia se nhanh.

## CSV Output

New trips are now exported to a single master file only:

```text
trips_master.csv
```

Each finished trip appends exactly one summary row to this file.

## Weather API

OpenWeather API key da duoc fallback trong code tai:
- `lib/src/config/app_secrets.dart`

Ban van co the override key khi run/build:

```bash
flutter run --dart-define=OPENWEATHER_API_KEY=YOUR_KEY
```

## Build APK nhanh

```bash
flutter build apk --release --target-platform android-arm64
```

APK output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

For a clean background-service verification run:

```bash
adb shell am force-stop com.evlogger.ev_data_logger
adb uninstall com.evlogger.ev_data_logger
flutter run
```

## Crash Diagnostics

### Dart-side crash log

The app writes uncaught Dart/Flutter errors to a plain-text file inside the
app's documents directory:

```
<app_documents>/crash_log.txt
```

Pull it from the device with:

```bash
adb shell run-as com.evlogger.ev_data_logger cat files/crash_log.txt
```

### Native / Android crash capture

When the app crashes with a native signal (SIGSEGV, SIGABRT, etc.) collect the
tombstone log before the device reboots or GC clears it:

```bash
adb logcat -v threadtime *:E flutter:V DEBUG:V crash_dump64:V
```

For ANR-focused capture (recommended when app shows "isn't responding"):

```bash
adb logcat -v threadtime ActivityManager:I InputDispatcher:I ANRManager:I crash_dump64:V *:S
```

ANR capture checklist:

1. Start recording logcat before tapping Start Trip.
2. Keep 20-30 lines before and after the first ANR/timeout line.
3. Include `Input dispatching timed out`, `ANR in ...`, and nearby `crash_dump64` lines.
4. If available, also attach `crash_log.txt` from app documents.

Capture at least 20-30 lines before the first `Fatal signal` / tombstone header
line. Include the full stack trace through the `backtrace:` block.

Alternatively pull the tombstone file directly:

```bash
adb shell ls /data/tombstones/
adb pull /data/tombstones/tombstone_00
```

> Note: `/data/tombstones/` requires root or `adb root`. On non-rooted devices,
> use `adb bugreport` to get a full zip containing tombstones.

### Reference

- Android crash debugger (ptrace attach path):
  https://android.googlesource.com/platform/system/core/+/master/debuggerd/crash_dump.cpp
- Android native crash debugging docs:
  https://source.android.com/docs/core/tests/debug/native-crash

