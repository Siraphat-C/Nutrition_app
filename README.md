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

## ui-v2: ต่อ backend จริง

แอปเรียก API ของ backend (branch `backend-dev`) ทุกหน้า ต้องเปิด backend ก่อนใช้งาน

| รันบน | ที่อยู่ backend ที่แอปใช้ |
|---|---|
| Chrome (เครื่องเดียวกับ backend) | `http://localhost:8000` (ค่าเริ่มต้น) |
| Android emulator ของ Android Studio | `http://10.0.2.2:8000` (ค่าเริ่มต้น) |
| มือถือจริง / LDPlayer / เครื่องอื่น | ต้องกำหนดเอง ด้วย `--dart-define=API_BASE=...` |

ตัวอย่าง: backend อยู่เครื่อง IP `192.168.1.25` (ดูด้วย `ipconfig`)

```sh
# เครื่องที่รัน backend
uvicorn main:app --reload --host 0.0.0.0

# เครื่องที่รันแอป
flutter run -d chrome --dart-define=API_BASE=http://192.168.1.25:8000
flutter build apk --dart-define=API_BASE=http://192.168.1.25:8000   # ลาก APK ใส่ LDPlayer
```

โครงสร้างโค้ด

```
lib/
  main.dart            เลือกหน้า: เข้าสู่ระบบ → ตั้งค่า → หน้าหลัก
  config.dart          ที่อยู่ backend
  api/api_client.dart  เรียก API ทุกตัว
  state/app_state.dart ข้อมูลผู้ใช้ มื้อวันนี้ การแจ้งเตือน
  screens/             หน้าจอแต่ละหน้า
  widgets/common.dart  การ์ด กราฟ ปุ่มที่ใช้ซ้ำ
  data/foods.dart      ชื่อไทยของ 12 เมนู
```

