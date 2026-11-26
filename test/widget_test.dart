import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nutrition_app/main.dart';
import 'package:nutrition_app/util.dart';

void main() {
  test('fmtInt ใส่จุลภาคหลักพัน', () {
    expect(fmtInt(1234.4), '1,234');
    expect(fmtInt(999), '999');
    expect(fmtInt(1000000), '1,000,000');
  });

  test('bmiCategory ใช้เกณฑ์คนไทย', () {
    expect(bmiCategory(18.4).label, 'น้ำหนักน้อยเกินไป');
    expect(bmiCategory(22.9).label, 'น้ำหนักปกติ');
    expect(bmiCategory(23.7).label, 'น้ำหนักเกินเล็กน้อย');
    expect(bmiCategory(27).label, 'อ้วน');
    expect(bmiCategory(31).label, 'อ้วนมาก');
  });

  test('allowedGoalsForBmi ปิดปุ่มเป้าหมายตาม BMI', () {
    // ตัวอย่างอาจารย์: สูง 160 หนัก 120 -> BMI 46.9 เพิ่มน้ำหนักไม่ได้
    expect(allowedGoalsForBmi(120 / (1.6 * 1.6)), ['lose']);
    expect(allowedGoalsForBmi(17.0), ['maintain', 'gain']);
    expect(allowedGoalsForBmi(21.0), ['lose', 'maintain', 'gain']);
    expect(allowedGoalsForBmi(null), ['lose', 'maintain', 'gain']);
  });

  testWidgets('เปิดแอปแล้วเห็นหน้าเข้าสู่ระบบ', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const NutritionApp());
    await tester.pumpAndSettle();
    expect(find.text('เข้าสู่ระบบ'), findsOneWidget);
    expect(find.text('สมัครสมาชิก'), findsOneWidget);
  });
}
