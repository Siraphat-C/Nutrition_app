import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:nutrition_app/main.dart';

void main() {
  testWidgets('Nutrition app opens and health setup route works', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const NutritionApp());
    await tester.pumpAndSettle();

    expect(find.text('วิเคราะห์โภชนาการ'), findsOneWidget);

    Navigator.of(tester.element(find.text('วิเคราะห์โภชนาการ')))
        .pushNamed('/health');
    await tester.pumpAndSettle();

    expect(find.text('ข้อมูลสุขภาพของคุณ'), findsOneWidget);
    expect(find.text('ถัดไป'), findsOneWidget);

    Navigator.of(tester.element(find.text('ข้อมูลสุขภาพของคุณ')))
        .pushNamed('/goal');
    await tester.pumpAndSettle();
    expect(find.text('ระดับกิจกรรมประจำวัน'), findsOneWidget);
    expect(find.text('น้อย'), findsOneWidget);
    expect(find.text('ปานกลาง'), findsOneWidget);
    expect(find.text('หนัก'), findsOneWidget);
  });

  testWidgets('registered user logs in and opens the dashboard', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final content = AppContent();
    await content.initialize();
    content.startNewAccount(
      name: 'นักทดสอบ ผู้ใช้',
      newEmail: 'tester@example.com',
      password: 'password123',
    );
    await content.updateAccountInfo(newBirthDate: DateTime(1999, 2, 3));
    await content.updateHealthProfile(weight: 62, height: 170);
    await content.completeRegistration();
    await content.logout();

    await tester.pumpWidget(const NutritionApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'tester@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('เข้าสู่ระบบ'));
    await tester.pumpAndSettle();

    expect(find.text('สวัสดี, นักทดสอบ'), findsOneWidget);
    expect(find.text('พลังงานวันนี้'), findsOneWidget);
    expect(find.text('ค่าพื้นฐานเมื่อเริ่มตั้งเป้าหมาย'), findsOneWidget);
    expect(find.byType(NextMealRecommendationCard), findsNothing);

    await tester.tap(find.text('วิเคราะห์'));
    await tester.pumpAndSettle();
    expect(find.text('คำแนะนำและการวิเคราะห์'), findsOneWidget);
    expect(find.byType(NextMealRecommendationCard), findsOneWidget);

    Navigator.of(
      tester.element(find.text('คำแนะนำและการวิเคราะห์')),
    ).pushNamed('/stats');
    await tester.pumpAndSettle();
    expect(find.text('เปรียบเทียบและสถิติพลังงาน'), findsOneWidget);

    await tester.tap(find.text('หน้าหลัก'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('โปรไฟล์'));
    await tester.pumpAndSettle();
    expect(find.text('บัญชี'), findsOneWidget);
    expect(find.text('ตั้งค่าแอป'), findsOneWidget);
    expect(find.text('เริ่มบันทึกมื้อแรกของคุณ'), findsOneWidget);
  });

  test(
    'accounts persist and validate credentials across app instances',
    () async {
      SharedPreferences.setMockInitialValues({});
      final firstApp = AppContent();
      await firstApp.initialize();

      expect(
        firstApp.startNewAccount(
          name: 'ผู้ใช้ทดสอบ',
          newEmail: 'Test@Example.com',
          password: 'password123',
        ),
        isTrue,
      );
      await firstApp.updateAccountInfo(newBirthDate: DateTime(1999, 2, 3));
      await firstApp.updateHealthProfile(
        weight: 62,
        height: 170,
        targetType: 'รักษาน้ำหนัก',
      );
      await firstApp.completeRegistration();
      await firstApp.logMeal(name: 'อาหารทดสอบ', calories: 420);
      expect(
        await firstApp.changePassword(
          oldPassword: 'wrong-password',
          newPassword: 'newPassword123',
        ),
        isFalse,
      );
      expect(
        await firstApp.changePassword(
          oldPassword: 'password123',
          newPassword: 'newPassword123',
        ),
        isTrue,
      );
      expect(
        await firstApp.updateAccountInfo(
          name: 'ชื่อที่แก้แล้ว',
          newEmail: 'updated@example.com',
        ),
        isTrue,
      );
      await firstApp.logout();

      final secondApp = AppContent();
      await secondApp.initialize();
      expect(secondApp.isLoggedIn, isFalse);
      expect(
        await secondApp.login('test@example.com', 'newPassword123'),
        isFalse,
      );
      expect(
        await secondApp.login('updated@example.com', 'password123'),
        isFalse,
      );
      expect(
        await secondApp.login('updated@example.com', 'newPassword123'),
        isTrue,
      );
      expect(secondApp.fullName, 'ชื่อที่แก้แล้ว');
      expect(secondApp.email, 'updated@example.com');
      expect(secondApp.weightKg, 62);
      expect(secondApp.heightCm, 170);
      expect(
        secondApp.mealsByDate.values.expand((meals) => meals),
        hasLength(1),
      );

      final restoredApp = AppContent();
      await restoredApp.initialize();
      expect(restoredApp.isLoggedIn, isTrue);
      expect(restoredApp.email, 'updated@example.com');
      await restoredApp.logout();
    },
  );
}
