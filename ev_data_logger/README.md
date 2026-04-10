# EV Trip Logger

App Flutter thu thap telemetry EV theo tung giay, xuat CSV va chia se nhanh.

## CSV Output

Trip summaries are exported to a single master file:

```text
trips_master.csv
```

Each finished trip appends exactly one summary row to this file.

Charging sessions are exported separately to:

```text
Charging_log.csv
```

Each finished charging session appends exactly one row to this file.

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

## Cloud Sync with Google Apps Script

The app can sync movement telemetry and charging sessions to a Google Sheet via
Google Apps Script webhooks in real-time.

### Quick Setup

1. Create a Google Apps Script project at https://script.google.com
2. Create two sheets in a Google Sheet:
   - `Movement` (for telemetry: timestamp, lat, lng, SOC, payload, etc.)
   - `Charging` (for charging sessions: start/end time, SOC delta, energy, etc.)
3. Copy the Apps Script code from `APPS_SCRIPT_SETUP.md` to your project
4. Deploy as Web App → note the URL (e.g., `https://script.google.com/macros/d/{ID}/usercopy`)
5. Set webhook URLs in `lib/src/config/app_secrets.dart`:
   ```dart
   const kMovementWebhookUrl = 'YOUR_APPS_SCRIPT_URL';
   const kChargingWebhookUrl = 'YOUR_APPS_SCRIPT_URL';
   const kDriveWebhookApiKey = 'YOUR_SECRET_KEY';
   ```
6. Rebuild and run. Sync status appears on Live and Export screens.

### Sync Features

- **Real-time movement**: Every 1-2s telemetry tick is batched (max 20 items) and sent to Google Sheet
- **Charging summary**: When charging session ends, summary is sent for logging
- **Offline resilience**: Queue persists locally; failed items retry with exponential backoff (1s → 5m max)
- **HTTP redirect handling**: Follows 301/302/303/307/308 Location headers automatically
- **API key flexibility**: Accepts key in request body or query parameter

### Payload Format

#### Batch Movement Request
```json
{
  "target": "movement",
  "key": "YOUR_API_KEY",
  "records": [
    {
      "timestamp": "2024-01-15T10:30:00Z",
      "latitude": 21.028511,
      "longitude": 105.852393,
      "accuracy": 5,
      "altitude": 20,
      "speed": 12.5,
      "heading": 180,
      "soc": 75,
      "payload_kg": 1500,
      "effective_payload_kg": 1565,
      "passenger_on": true,
      "voltage": 400,
      "current": 2.5,
      "temperature": 45
    },
    ...
  ]
}
```

#### Single Charging Request
```json
{
  "target": "charging",
  "key": "YOUR_API_KEY",
  "record": {
    "start_time": "2024-01-15T08:00:00Z",
    "end_time": "2024-01-15T09:30:00Z",
    "start_soc": 20,
    "end_soc": 80,
    "duration_minutes": 90,
    "energy_added_kwh": 45,
    "location": "DC Fast Charger - Hà Nội",
    "charger_type": "150kW DC",
    "payload_kg": 1500
  }
}
```

#### Expected Response
```json
{
  "status": "ok",
  "target": "movement",
  "accepted": 20
}
```

### Monitoring Sync

- **Live Screen**: Shows real-time sync queue count and last error (if any)
- **Export Screen**: Displays sync status card with pending count, last success, and error details
- **Local Fallback**: If sync fails, data remains in local CSV files and retries automatically

### Troubleshooting

- **401 Unauthorized**: API key mismatch between Flutter config and Apps Script
- **HTTP 302 Redirect**: Automatically handled; verify Apps Script deployment URL
- **Sheet Not Found**: Check sheet name case sensitivity (Motion vs Charging)
- **Batch stalling**: Check queue in Export screen; if >500 items, may indicate webhook failure
- **Sync disabled**: Verify webhook URLs are non-empty in `app_secrets.dart`

For full Apps Script setup details, see [APPS_SCRIPT_SETUP.md](./APPS_SCRIPT_SETUP.md).

