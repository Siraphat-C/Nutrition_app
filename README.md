# Nutrition App

Flutter application for nutrition tracking and food image capture.

## Requirements

- Flutter stable with Dart SDK `3.14.0` or newer, as specified in `pubspec.yaml`.
- Android development: Android Studio, Android SDK, and a JDK supported by the installed Flutter/Android Gradle Plugin.
- Windows desktop development: Visual Studio with the **Desktop development with C++** workload.
- iOS/macOS development: macOS with Xcode.
- Web development: a supported browser.

## Run on a new computer

1. Install Flutter and the tooling for the target platform, then add Flutter's `bin` directory to `PATH`.
2. Clone this repository and open a terminal in the repository root.
3. Fetch the locked dependencies:

   ```sh
   flutter doctor
   flutter pub get
   ```

4. List available targets and run the app:

   ```sh
   flutter devices
   flutter run -d <device-id>
   ```

   For example, use `flutter run -d windows` for Windows desktop or `flutter run -d <emulator-id>` for Android.

`android/local.properties` contains machine-specific SDK paths and is intentionally not committed. Let Flutter generate it on the new computer; do not copy this file from another computer. Do not commit generated build files or local signing credentials.

## Validate

```sh
flutter analyze
flutter test
```

Build examples:

```sh
flutter build apk
flutter build web
flutter build windows
```

Camera and photo-library access require the platform permissions configured in the Android, iOS, and macOS runner files. Camera hardware is optional; the app can still open without a camera.
