# EV Data Logger

App Flutter thu thap telemetry EV theo tung giay, xuat CSV va chia se nhanh.

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