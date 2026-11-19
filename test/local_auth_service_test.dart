import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nutrition_app/auth_service.dart';
import 'package:nutrition_app/main.dart';

void main() {
  test(
    'local signup saves credentials and profile across app restarts',
    () async {
      SharedPreferences.setMockInitialValues({});
      final auth = await LocalAuthService.create();
      final app = AppContent(authService: auth);
      await app.initialize();

      expect(
        app.startNewAccount(
          name: 'ผู้ใช้ทดสอบ',
          newEmail: 'Test@Example.com',
          password: 'password123',
        ),
        isTrue,
      );
      await app.updateAccountInfo(newBirthDate: DateTime(1999, 2, 3));
      await app.updateHealthProfile(
        weight: 62,
        height: 170,
        targetType: 'เพิ่มน้ำหนัก',
      );
      expect(await app.completeRegistration(), isTrue);
      expect(app.isLoggedIn, isTrue);
      expect(app.email, 'test@example.com');

      final preferences = await SharedPreferences.getInstance();
      final storedAuth = preferences.getString(
        'nutrition_local_auth_accounts_v1',
      );
      expect(storedAuth, isNotNull);
      expect(storedAuth, isNot(contains('password123')));
      expect(
        (jsonDecode(storedAuth!) as List).single['passwordHash'],
        isNotEmpty,
      );

      await app.logMeal(name: 'อาหารทดสอบ', calories: 420);
      await app.logout();

      final restoredAuth = await LocalAuthService.create();
      final restoredApp = AppContent(authService: restoredAuth);
      await restoredApp.initialize();
      expect(restoredApp.isLoggedIn, isFalse);
      expect(
        await restoredApp.login('TEST@example.com', 'password123'),
        isTrue,
      );
      expect(restoredApp.fullName, 'ผู้ใช้ทดสอบ');
      expect(restoredApp.weightKg, 62);
      expect(restoredApp.heightCm, 170);
      expect(restoredApp.goalType, 'เพิ่มน้ำหนัก');
      expect(
        restoredApp.mealsByDate.values.expand((meals) => meals),
        hasLength(1),
      );
    },
  );

  test(
    'local authentication rejects duplicate accounts and bad passwords',
    () async {
      SharedPreferences.setMockInitialValues({});
      final auth = await LocalAuthService.create();

      await auth.signUp(
        name: 'ผู้ใช้ทดสอบ',
        email: 'tester@example.com',
        password: 'password123',
      );

      expect(
        auth.signUp(
          name: 'ผู้ใช้ซ้ำ',
          email: 'TESTER@example.com',
          password: 'password123',
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        await auth.signIn(email: 'tester@example.com', password: 'wrongpass'),
        isFalse,
      );
      expect(
        await auth.signIn(email: 'tester@example.com', password: 'password123'),
        isTrue,
      );
      expect(
        await auth.changePassword(
          oldPassword: 'password123',
          newPassword: 'newPassword123',
        ),
        isTrue,
      );
      await auth.signOut();
      expect(
        await auth.signIn(
          email: 'tester@example.com',
          password: 'newPassword123',
        ),
        isTrue,
      );
    },
  );
}
