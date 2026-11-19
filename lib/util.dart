import 'package:material_ui/material_ui.dart';

import 'theme.dart';

/// 1234.5 -> "1,235"
String fmtInt(num value) {
  final s = value.round().abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return value < 0 ? '-$buf' : buf.toString();
}

String fmtTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

const _thaiMonths = [
  'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];
const _thaiDays = ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์'];

/// วันพฤหัสบดี 19 พฤศจิกายน 2569
String fmtThaiDate(DateTime d) =>
    'วัน${_thaiDays[d.weekday - 1]} ${d.day} ${_thaiMonths[d.month - 1]} ${d.year + 543}';

String fmtThaiShortDate(DateTime d) => '${d.day} ${_thaiMonths[d.month - 1]} ${d.year + 543}';

/// เกณฑ์ BMI คนเอเชีย/คนไทย
({String label, Color color}) bmiCategory(double bmi) {
  if (bmi < 18.5) return (label: 'ผอม', color: kBlue);
  if (bmi < 23) return (label: 'ปกติ', color: kGreenText);
  if (bmi < 25) return (label: 'ท้วม', color: kOrangeText);
  if (bmi < 30) return (label: 'อ้วนระดับ 1', color: kRedText);
  return (label: 'อ้วนระดับ 2', color: kRedText);
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? kRedText : kInk,
      behavior: SnackBarBehavior.floating,
    ));
}

/// ชื่อผู้ใช้: ไทย อังกฤษ ตัวเลข _ . เว้นวรรคได้ทีละ 1 ช่องระหว่างคำ (ตรงกับ backend)
final usernamePattern = RegExp(r'^[A-Za-z0-9_.฀-๿]+( [A-Za-z0-9_.฀-๿]+)*$');

/// ตัดเว้นวรรคหัวท้าย และรวมเว้นวรรคซ้อนเป็นช่องเดียว
String cleanUsername(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

String? validateUsername(String? v) {
  final s = cleanUsername(v ?? '');
  if (s.length < 3 || s.length > 50) return 'ต้องยาว 3–50 ตัวอักษร';
  if (!usernamePattern.hasMatch(s)) return 'ใช้ได้เฉพาะตัวอักษรไทย/อังกฤษ ตัวเลข _ . และเว้นวรรค';
  return null;
}

