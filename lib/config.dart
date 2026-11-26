import 'package:flutter/foundation.dart';

/// ที่อยู่ backend
/// - เปลี่ยนได้ตอนรัน: flutter run --dart-define=API_BASE=http://192.168.1.10:8000
/// - ไม่กำหนด: เว็บใช้ localhost, Android emulator ใช้ 10.0.2.2
String get apiBase {
  const fromEnv = String.fromEnvironment('API_BASE');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8000';
  }
  return 'http://localhost:8000';
}
