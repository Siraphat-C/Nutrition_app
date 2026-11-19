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
    expect(bmiCategory(18.4).label, 'ผอม');
    expect(bmiCategory(22.9).label, 'ปกติ');
    expect(bmiCategory(23.7).label, 'ท้วม');
    expect(bmiCategory(27).label, 'อ้วนระดับ 1');
    expect(bmiCategory(31).label, 'อ้วนระดับ 2');
  });

  testWidgets('เปิดแอปแล้วเห็นหน้าเข้าสู่ระบบ', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const NutritionApp());
    await tester.pumpAndSettle();
    expect(find.text('เข้าสู่ระบบ'), findsOneWidget);
    expect(find.text('สมัครสมาชิก'), findsOneWidget);
  });
}
