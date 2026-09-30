# StallPOS Example Host App

This is the example host application demonstrating how to consume the `counter_app` / `stall_pos` package as a modular Flutter dependency.

## Features
- Modular consumption of the POS package and centralized storage.
- Interactive cloud backend switcher (Local SharedPreferences vs Remote REST API).
- Multiplatform support: Web and Android.

## Building & Running

### Android
```bash
# Debug run
flutter run -d android

# Build release APK
flutter build apk --release
```
The compiled APK will be generated at `build/app/outputs/flutter-apk/app-release.apk`.

### Web
```bash
# Debug run
flutter run -d chrome

# Build release bundle
flutter build web --release --base-href "/stall-pos/"
```
The compiled web bundle will be generated at `build/web/`.
