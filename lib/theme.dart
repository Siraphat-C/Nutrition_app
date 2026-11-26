import 'package:material_ui/material_ui.dart';

// สีหลักชุดเดิมของแอป
const kGreen = Color(0xFF20C96A);
const kGreenDark = Color(0xFF0E9F55);
const kGreenText = Color(0xFF0B7A42); // เขียวเข้มสำหรับตัวหนังสือ (อ่านง่ายบนพื้นขาว)
const kGreenBg = Color(0xFFE8F8EF);
const kInk = Color(0xFF1E293B);
const kMuted = Color(0xFF64748B);
const kBorder = Color(0xFFE2E8F0);
const kSurface = Color(0xFFF6F8FA);
const kRed = Color(0xFFFF4D4F);
const kRedText = Color(0xFFB3261E);
const kRedBg = Color(0xFFFFF1F0);
const kBlue = Color(0xFF4285F4);
const kOrange = Color(0xFFFBBC05);
const kOrangeText = Color(0xFFA15C00);
const kOrangeBg = Color(0xFFFFF4E5);
const kPurple = Color(0xFF8B5CF6);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: kGreen, primary: kGreenDark),
    scaffoldBackgroundColor: kSurface,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: kSurface,
      foregroundColor: kInk,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kInk),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kGreen, width: 2)),
      labelStyle: const TextStyle(color: kMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kGreenText,
        minimumSize: const Size(64, 50),
        side: const BorderSide(color: kBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
