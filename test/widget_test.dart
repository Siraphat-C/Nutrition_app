import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:nutrition_app/auth_service.dart';
import 'package:nutrition_app/main.dart';

void main() {
  testWidgets('Nutrition app opens and health setup route works', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(NutritionApp(authService: MemoryAuthService()));
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
    final auth = MemoryAuthService();
    final content = AppContent(authService: auth);
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

    await tester.pumpWidget(NutritionApp(authService: auth));
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

    Navigator.of(tester.element(find.text('คำแนะนำและการวิเคราะห์')))
        .pushNamed('/stats');
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
      final auth = MemoryAuthService();
      final firstApp = AppContent(authService: auth);
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

      final secondApp = AppContent(authService: auth);
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

      final restoredApp = AppContent(authService: auth);
      await restoredApp.initialize();
      expect(restoredApp.isLoggedIn, isTrue);
      expect(restoredApp.email, 'updated@example.com');
      await restoredApp.logout();
    },
  );
}

class MemoryAuthService implements AuthService {
  final Map<String, ({String name, String password})> _accounts = {};
  String? _email;

  @override
  String? get currentEmail => _email;

  @override
  String? get currentName => _email == null ? null : _accounts[_email]?.name;

  @override
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.toLowerCase();
    if (_accounts.containsKey(normalizedEmail)) {
      throw StateError('อีเมลนี้มีบัญชีอยู่แล้ว');
    }
    _accounts[normalizedEmail] = (name: name, password: password);
    _email = normalizedEmail;
    return true;
  }

  @override
  Future<bool> signIn({required String email, required String password}) async {
    final normalizedEmail = email.toLowerCase();
    if (_accounts[normalizedEmail]?.password != password) {
      return false;
    }
    _email = normalizedEmail;
    return true;
  }

  @override
  Future<void> signOut() async {
    _email = null;
  }

  @override
  Future<String?> updateEmail(String email) async {
    final account = _accounts.remove(_email);
    if (account == null) return null;
    final normalizedEmail = email.toLowerCase();
    _accounts[normalizedEmail] = account;
    _email = normalizedEmail;
    return normalizedEmail;
  }

  @override
  Future<void> updateName(String name) async {
    if (_email == null) return;
    _accounts[_email!] = (name: name, password: _accounts[_email!]!.password);
  }

  @override
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (_email == null || _accounts[_email!]?.password != oldPassword) {
      return false;
    }
    _accounts[_email!] = (
      name: _accounts[_email!]!.name,
      password: newPassword,
    );
    return true;
  }
}
