import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

// ───────────────────────── Type Definitions ─────────────────────────
typedef StringMap = Map<String, String>;
typedef DynamicMap = Map<String, dynamic>;

import 'screens/admin_screens.dart';
import 'screens/auth_screens.dart';
import 'screens/home_shell.dart';
import 'screens/setup_screen.dart';
import 'state/app_state.dart';
import 'theme.dart';

const _useLocalAuth = bool.fromEnvironment(
  'LOCAL_AUTH',
  defaultValue: true,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final initialization = _initializeAuth();
  runApp(NutritionStartupApp(initialization: initialization));
  unawaited(_loadCameras());
}

Future<AuthService> _initializeAuth() {
  if (_useLocalAuth) return LocalAuthService.create();
  return _initializeSupabase();
}

Future<AuthService> _initializeSupabase() async {
  try {
    await dotenv.load(fileName: 'assets/app.env');
  } on Object catch (error) {
    throw StateError(
      'โหลดไฟล์ assets/app.env ไม่สำเร็จ (${error.runtimeType}) '
      'ตรวจว่ามีไฟล์นี้ แล้ว build แอปใหม่',
    );
  }
  final supabaseUrl = dotenv.env['SUPABASE_URL']?.trim() ?? '';
  final publishableKey = dotenv.env['SUPABASE_PUBLISHABLE_KEY']?.trim() ?? '';
  if (supabaseUrl.isEmpty || publishableKey.isEmpty) {
    throw StateError(
      'ไม่พบ SUPABASE_URL หรือ SUPABASE_PUBLISHABLE_KEY ใน assets/app.env',
    );
  }
  try {
    await Supabase.initialize(url: supabaseUrl, publishableKey: publishableKey);
  } on Object catch (error) {
    throw StateError(
      'เริ่มต้น Supabase ไม่สำเร็จ (${error.runtimeType}) '
      'ตรวจ Project URL, Publishable key และการเชื่อมต่ออินเทอร์เน็ต',
    );
  }
  return SupabaseAuthService(Supabase.instance.client);
}

Future<void> _loadCameras() async {
  try {
    cameras = await availableCameras();
  } on CameraException catch (error) {
    cameras = [];
    debugPrint('Camera initialization failed: $error');
  }
}

// ───────────────────────── Admin Auth State ─────────────────────────
class AdminAuth extends ChangeNotifier {
  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;

  bool login(String email, String password) {
    if (email.trim().isEmpty || password.trim().length < 4) {
      return false;
    }
    _isAdmin = true;
    notifyListeners();
    return true;
  }

  void logout() {
    _isAdmin = false;
    notifyListeners();
  }
}

// ───────────────────────── App Data State ─────────────────────────
class AppContent extends ChangeNotifier {
  final AuthService authService;

  final Map<String, StringMap> users = {
    '6701': {
      'name': 'แคทเธอรีน ภูชาง',
      'email': 'Doradaymon@gmail.com',
      'role': 'ผู้ใช้งาน',
    },
    '6702': {
      'name': 'ปิติโชค โดราเอม่อน',
      'email': 'user2@gmail.com',
      'role': 'ผู้ใช้งาน',
    },
  };

  final List<StringMap> foods = [
    {
      'id': 'f1',
      'name': 'ข้าวมันไก่ต้ม',
      'engName': 'Khao_mun_gai',
      'energy': '590',
      'serving': '1 จาน (310 กรัม)',
      'category': 'อาหารจานเดียว',
      'source': 'admin',
    },
    {
      'id': 'f2',
      'name': 'สุกี้น้ำรวมมิตร',
      'engName': 'Suki_nam_ruam_mit',
      'energy': '320',
      'serving': '1 ชาม (350 กรัม)',
      'category': 'อาหารสุขภาพ',
      'source': 'admin',
    },
    {
      'id': 'f3',
      'name': 'ข้าวกระเพราหมูสับไข่ดาว',
      'engName': 'Pad_krapow_moo_sub',
      'energy': '540',
      'serving': '1 จาน (285 กรัม)',
      'category': 'อาหารจานเดียว',
      'source': 'admin',
    },
    {
      'id': 'f4',
      'name': 'สลัดอกไก่ย่างงาญี่ปุ่น',
      'engName': 'Grilled_chicken_salad',
      'energy': '290',
      'serving': '1 กล่อง (250 กรัม)',
      'category': 'อาหารสุขภาพ',
      'source': 'admin',
    },
    {
      'id': 'f5',
      'name': 'เกาเหลาเลือดหมู + ข้าวเปล่าครึ่งทัพพี',
      'engName': 'Clear_pork_soup_rice',
      'energy': '340',
      'serving': '1 ชุด (380 กรัม)',
      'category': 'อาหารสุขภาพ',
      'source': 'admin',
    },
    {
      'id': 'f6',
      'name': 'ก๋วยเตี๋ยวน้ำใสลูกชิ้นปลา',
      'engName': 'Fish_ball_noodle_soup',
      'energy': '330',
      'serving': '1 ชาม (340 กรัม)',
      'category': 'ก๋วยเตี๋ยว/เส้น',
      'source': 'admin',
    },
    {
      'id': 'f7',
      'name': 'ยำวุ้นเส้นทะเลรวมมิตร',
      'engName': 'Spicy_glass_noodle_salad',
      'energy': '240',
      'serving': '1 จาน (250 กรัม)',
      'category': 'อาหารสุขภาพ',
      'source': 'admin',
    },
    {
      'id': 'f8',
      'name': 'ไข่ต้ม 2 ฟอง + กล้วยหอม 1 ลูก',
      'engName': 'Boiled_eggs_banana',
      'energy': '250',
      'serving': '1 ชุด (220 กรัม)',
      'category': 'ของว่าง/เครื่องดื่ม',
      'source': 'admin',
    },
    {
      'id': 'f9',
      'name': 'ข้าวอกไก่ย่างจิ้มแจ่ว',
      'engName': 'Grilled_chicken_rice',
      'energy': '450',
      'serving': '1 จาน (290 กรัม)',
      'category': 'อาหารสุขภาพ',
      'source': 'admin',
    },
  ];

  final Map<String, List<DynamicMap>> mealsByDate = {};

  DateTime selectedDate = DateTime.now();
  DateTime? birthDate;
  String fullName = '';
  String email = '';
  double weightKg = 0;
  double heightCm = 0;
  String gender = 'หญิง';
  String activityLevel = 'ปานกลาง (ออกกำลังกายสม่ำเสมอ)';
  String goalType = 'ลดน้ำหนัก';
  SharedPreferences? _preferences;
  final List<DynamicMap> _accounts = [];
  String? _currentAccountEmail;
  String? _pendingName;
  String? _pendingEmail;
  String? _pendingPassword;

  bool get isLoggedIn => _currentAccountEmail != null;

  static const _accountsKey = 'nutrition_accounts_v1';

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    final storedAccounts = _preferences!.getString(_accountsKey);
    var removedLocalCredentials = false;
    if (storedAccounts != null) {
      final decoded = jsonDecode(storedAccounts);
      if (decoded is! List) {
        throw const FormatException('ข้อมูลบัญชีในเครื่องมีรูปแบบไม่ถูกต้อง');
      }
      _accounts
        ..clear()
        ..addAll(decoded.map((item) => Map<String, dynamic>.from(item as Map)));
      for (final account in _accounts) {
        removedLocalCredentials =
            account.remove('passwordHash') != null || removedLocalCredentials;
        removedLocalCredentials =
            account.remove('passwordSalt') != null || removedLocalCredentials;
      }
    }
    await _preferences!.remove('nutrition_current_account');

    final currentEmail = authService.currentEmail;
    if (currentEmail != null) {
      final account =
          _findAccount(currentEmail) ??
          _newLocalProfile(currentEmail, authService.currentName);
      if (!_accounts.contains(account)) _accounts.add(account);
      _loadAccount(account);
      await _saveAccounts();
    } else if (removedLocalCredentials) {
      await _saveAccounts();
    }
  }

  DynamicMap? _findAccount(String? accountEmail) {
    if (accountEmail == null) return null;
    final normalizedEmail = accountEmail.trim().toLowerCase();
    for (final account in _accounts) {
      if ((account['email'] as String).toLowerCase() == normalizedEmail) {
        return account;
      }
    }
    return null;
  }

  DynamicMap _newLocalProfile(String accountEmail, String? accountName) => {
    'name': accountName?.trim().isNotEmpty == true
        ? accountName!.trim()
        : accountEmail.split('@').first,
    'email': accountEmail,
  };

  bool startNewAccount({
    required String name,
    required String newEmail,
    required String password,
  }) {
    final normalizedEmail = newEmail.trim().toLowerCase();

    _pendingName = name.trim();
    _pendingEmail = normalizedEmail;
    _pendingPassword = password;
    fullName = _pendingName!;
    email = normalizedEmail;
    birthDate = null;
    weightKg = 0;
    heightCm = 0;
    gender = 'หญิง';
    activityLevel = 'ปานกลาง (ออกกำลังกายสม่ำเสมอ)';
    goalType = 'รักษาน้ำหนัก';
    mealsByDate.clear();
    selectedDate = DateTime.now();
    notifyListeners();
    return true;
  }

  Future<bool> completeRegistration() async {
    final name = _pendingName;
    final pendingEmail = _pendingEmail;
    final password = _pendingPassword;
    if (name == null || pendingEmail == null || password == null) {
      throw StateError('ไม่พบข้อมูลสมัครสมาชิก กรุณาเริ่มสมัครใหม่');
    }
    final hasSession = await authService.signUp(
      name: name,
      email: pendingEmail,
      password: password,
    );
    final account =
        _findAccount(pendingEmail) ?? _newLocalProfile(pendingEmail, name);
    _writeAccountData(account);
    if (!_accounts.contains(account)) _accounts.add(account);
    await _saveAccounts();
    _pendingName = null;
    _pendingEmail = null;
    _pendingPassword = null;
    if (hasSession) {
      _loadAccount(account);
    } else {
      _currentAccountEmail = null;
    }
    notifyListeners();
    return hasSession;
  }

  Future<bool> login(String accountEmail, String password) async {
    final success = await authService.signIn(
      email: accountEmail.trim(),
      password: password,
    );
    if (!success) return false;
    final normalizedEmail = (authService.currentEmail ?? accountEmail)
        .trim()
        .toLowerCase();
    final account =
        _findAccount(normalizedEmail) ??
        _newLocalProfile(normalizedEmail, authService.currentName);
    if (!_accounts.contains(account)) _accounts.add(account);
    _loadAccount(account);
    await _saveAccounts();
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    await authService.signOut();
    _currentAccountEmail = null;
    notifyListeners();
  }

  Future<bool> updateAccountInfo({
    String? name,
    String? newEmail,
    DateTime? newBirthDate,
  }) async {
    final normalizedEmail = newEmail?.trim().toLowerCase();
    if (normalizedEmail != null &&
        normalizedEmail != _currentAccountEmail &&
        _findAccount(normalizedEmail) != null) {
      return false;
    }
    final currentAccount = _findAccount(_currentAccountEmail);
    if (name != null && name.isNotEmpty) {
      await authService.updateName(name);
      fullName = name;
    }
    if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
      final updatedEmail = await authService.updateEmail(normalizedEmail);
      if (updatedEmail == null ||
          updatedEmail.trim().toLowerCase() != normalizedEmail) {
        return false;
      }
      if (currentAccount != null) currentAccount['email'] = normalizedEmail;
      email = normalizedEmail;
      _currentAccountEmail = normalizedEmail;
    }
    if (newBirthDate != null) birthDate = newBirthDate;
    await _persistCurrentAccount();
    notifyListeners();
    return true;
  }

  Future<void> updateHealthProfile({
    double? weight,
    double? height,
    String? userGender,
    String? activity,
    String? targetType,
  }) async {
    if (weight != null) weightKg = weight;
    if (height != null) heightCm = height;
    if (userGender != null) gender = userGender;
    if (activity != null) activityLevel = activity;
    if (targetType != null) goalType = targetType;
    await _persistCurrentAccount();
    notifyListeners();
  }

  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (_currentAccountEmail == null) return false;
    return authService.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }

  void _loadAccount(DynamicMap account) {
    _currentAccountEmail = account['email'] as String;
    fullName = account['name'] as String;
    email = _currentAccountEmail!;
    birthDate = DateTime.tryParse(account['birthDate'] as String? ?? '');
    weightKg = (account['weightKg'] as num?)?.toDouble() ?? 0;
    heightCm = (account['heightCm'] as num?)?.toDouble() ?? 0;
    gender = account['gender'] as String? ?? 'หญิง';
    activityLevel =
        account['activityLevel'] as String? ?? 'ปานกลาง (ออกกำลังกายสม่ำเสมอ)';
    goalType = account['goalType'] as String? ?? 'รักษาน้ำหนัก';
    final storedMeals = account['mealsByDate'];
    mealsByDate
      ..clear()
      ..addAll(
        storedMeals is Map
            ? storedMeals.map(
                (key, value) => MapEntry(
                  key.toString(),
                  (value as List)
                      .map((meal) => Map<String, dynamic>.from(meal as Map))
                      .toList(),
                ),
              )
            : <String, List<DynamicMap>>{},
      );
    selectedDate = DateTime.now();
  }

  void _writeAccountData(DynamicMap account) {
    account
      ..['name'] = fullName
      ..['email'] = email
      ..['birthDate'] = birthDate?.toIso8601String()
      ..['weightKg'] = weightKg
      ..['heightCm'] = heightCm
      ..['gender'] = gender
      ..['activityLevel'] = activityLevel
      ..['goalType'] = goalType
      ..['mealsByDate'] = mealsByDate;
  }

  Future<void> _persistCurrentAccount() async {
    final account = _findAccount(_currentAccountEmail);
    if (account == null) return;
    _writeAccountData(account);
    await _saveAccounts();
  }

  Future<void> _saveAccounts() async {
    final saved = await _preferences!.setString(
      _accountsKey,
      jsonEncode(_accounts),
    );
    if (!saved) throw StateError('บันทึกข้อมูลบัญชีลงในอุปกรณ์ไม่สำเร็จ');
  }

  double get dailyGoal => calculateRecommendedTDEE();
  double get basalMetabolicRate {
    final weight = weightKg > 0 ? weightKg : 55.0;
    final height = heightCm > 0 ? heightCm : 165.0;
    return _calculateBmr(weight, height, gender);
  }

  double get maintenanceTdee =>
      calculateRecommendedTDEE(forGoal: 'รักษาน้ำหนัก');

  double _calculateBmr(double weight, double height, String userGender) {
    return userGender == 'ชาย'
        ? (10 * weight) + (6.25 * height) - (5 * age) + 5
        : (10 * weight) + (6.25 * height) - (5 * age) - 161;
  }

  AppContent({required this.authService}) {
    final now = DateTime.now();
    final todayKey = dateKey(now);
    final yesterdayKey = dateKey(now.subtract(const Duration(days: 1)));
    final twoDaysAgoKey = dateKey(now.subtract(const Duration(days: 2)));
    final threeDaysAgoKey = dateKey(now.subtract(const Duration(days: 3)));

    mealsByDate[threeDaysAgoKey] = [
      {
        'id': 'd3_1',
        'name': 'สลัดอกไก่ย่างงาญี่ปุ่น',
        'calories': 290.0,
        'weightGrams': 250,
        'mealType': 'มื้อเช้า',
        'time': '08:30',
      },
      {
        'id': 'd3_2',
        'name': 'ข้าวกระเพราหมูสับไข่ดาว',
        'calories': 540.0,
        'weightGrams': 285,
        'mealType': 'มื้อกลางวัน',
        'time': '12:20',
      },
      {
        'id': 'd3_3',
        'name': 'สุกี้น้ำรวมมิตร',
        'calories': 320.0,
        'weightGrams': 350,
        'mealType': 'มื้อเย็น',
        'time': '18:40',
      },
    ];

    mealsByDate[twoDaysAgoKey] = [
      {
        'id': 'd2_1',
        'name': 'โจ๊กหมูใส่ไข่',
        'calories': 280.0,
        'weightGrams': 300,
        'mealType': 'มื้อเช้า',
        'time': '07:50',
      },
      {
        'id': 'd2_2',
        'name': 'ข้าวมันไก่ต้ม',
        'calories': 590.0,
        'weightGrams': 310,
        'mealType': 'มื้อกลางวัน',
        'time': '12:45',
      },
      {
        'id': 'd2_3',
        'name': 'เกาเหลาหมูตุ๋น',
        'calories': 310.0,
        'weightGrams': 320,
        'mealType': 'มื้อเย็น',
        'time': '19:10',
      },
    ];

    mealsByDate[yesterdayKey] = [
      {
        'id': 'y1',
        'name': 'โจ๊กหมูใส่ไข่',
        'calories': 280.0,
        'weightGrams': 300,
        'mealType': 'มื้อเช้า',
        'time': '08:15',
      },
      {
        'id': 'y2',
        'name': 'สุกี้น้ำรวมมิตร',
        'calories': 320.0,
        'weightGrams': 350,
        'mealType': 'มื้อกลางวัน',
        'time': '12:30',
      },
      {
        'id': 'y3',
        'name': 'ข้าวอกไก่ย่างจิ้มแจ่ว',
        'calories': 450.0,
        'weightGrams': 290,
        'mealType': 'มื้อเย็น',
        'time': '18:45',
      },
    ];

    mealsByDate[todayKey] = [
      {
        'id': 'm1',
        'name': 'ข้าวมันไก่ต้ม',
        'calories': 590.0,
        'weightGrams': 310,
        'mealType': 'มื้อกลางวัน',
        'time': '12:15',
      },
    ];
  }

  String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime parseDateKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return DateTime.now();
    return DateTime(
      int.tryParse(parts[0]) ?? DateTime.now().year,
      int.tryParse(parts[1]) ?? 1,
      int.tryParse(parts[2]) ?? 1,
    );
  }

  List<DynamicMap> get currentMeals => mealsByDate[dateKey(selectedDate)] ?? [];

  double caloriesForDate(DateTime date) {
    final list = mealsByDate[dateKey(date)] ?? [];
    return list.fold(
      0.0,
      (sum, item) => sum + ((item['calories'] as num?)?.toDouble() ?? 0.0),
    );
  }

  double caloriesByMealType(String mealType) {
    return currentMeals
        .where((m) => (m['mealType'] as String? ?? 'มื้อว่าง') == mealType)
        .fold(
          0.0,
          (sum, item) => sum + ((item['calories'] as num?)?.toDouble() ?? 0.0),
        );
  }

  // ── ระบุชื่อมื้อถัดไปอัตโนมัติจากมื้อที่บันทึกแล้วหรือเวลาปัจจุบัน ──
  String get suggestedNextMealType {
    final loggedTypes = currentMeals
        .map((m) => m['mealType'] as String? ?? '')
        .toSet();
    final hour = DateTime.now().hour;

    if (!loggedTypes.contains('มื้อเช้า') && hour < 11) return 'มื้อเช้า';
    if (!loggedTypes.contains('มื้อกลางวัน') && hour < 15) return 'มื้อกลางวัน';
    if (!loggedTypes.contains('มื้อเย็น')) return 'มื้อเย็น';
    return 'มื้อว่าง';
  }

  // ── ระบบแนะนำอาหารมื้อถัดไปตามโควตาแคลอรี่ที่เหลือ ──
  List<DynamicMap> getRecommendedNextMeals({
    double? customRemainingQuota,
    String? excludeMenuName,
    int limit = 4,
  }) {
    final remaining = customRemainingQuota ?? (dailyGoal - totalDailyCalories);

    if (remaining <= 80) {
      return [
        {
          'id': 'low_1',
          'name': 'น้ำเปล่า หรือ ชาเขียวร้อน/เย็นไม่หวาน',
          'energy': 0.0,
          'serving': '1 แก้ว (250 มล.)',
          'category': 'เครื่องดื่มปลอดแคลอรี่',
          'fitReason':
              'โควตาวันนี้เต็มแล้ว เหมาะสำหรับดื่มเพื่อลดความอยากอาหาร',
        },
        {
          'id': 'low_2',
          'name': 'ฝรั่งสด 4-5 ชิ้นพอดีคำ',
          'energy': 45.0,
          'serving': '1 จานเล็ก (80 กรัม)',
          'category': 'ผลไม้แคลอรี่ต่ำ',
          'fitReason': 'กากใยสูง ช่วยให้อิ่มท้องโดยไม่เพิ่มพลังงานเกินเกณฑ์',
        },
      ];
    }

    final candidates = foods
        .map((f) {
          final kcal = double.tryParse(f['energy'] ?? '0') ?? 0.0;
          return {
            'id': f['id'] ?? '',
            'name': f['name'] ?? '',
            'energy': kcal,
            'serving': f['serving'] ?? '1 จาน',
            'category': f['category'] ?? 'อาหารทั่วไป',
          };
        })
        .where((item) {
          final kcal = item['energy'] as double;
          final name = item['name'] as String;
          if (kcal <= 0 || kcal > remaining) return false;
          if (excludeMenuName != null && name == excludeMenuName) return false;
          return true;
        })
        .toList();

    // จัดลำดับเมนูที่เหมาะสมตามเป้าหมายของผู้ใช้
    if (goalType.contains('ลดน้ำหนัก')) {
      // ลดน้ำหนัก: แนะนำเมนูสุขภาพหรือเมนูที่อยู่ในช่วง 240 - 450 kcal เป็นลำดับแรก
      candidates.sort((a, b) {
        final aHealth = (a['category'] == 'อาหารสุขภาพ') ? 0 : 1;
        final bHealth = (b['category'] == 'อาหารสุขภาพ') ? 0 : 1;
        if (aHealth != bHealth) return aHealth.compareTo(bHealth);
        return (a['energy'] as double).compareTo(b['energy'] as double);
      });
    } else if (goalType.contains('เพิ่มน้ำหนัก')) {
      // เพิ่มน้ำหนัก: เรียงเมนูพลังงานสูงที่อยู่ในโควตาขึ้นก่อน
      candidates.sort(
        (a, b) => (b['energy'] as double).compareTo(a['energy'] as double),
      );
    } else {
      // รักษาน้ำหนัก: เรียงเมนูที่ใกล้เคียง 35% ของเป้าหมายวัน (ประมาณ 1 มื้อมาตรฐาน)
      final idealMeal = dailyGoal * 0.35;
      candidates.sort((a, b) {
        final diffA = ((a['energy'] as double) - idealMeal).abs();
        final diffB = ((b['energy'] as double) - idealMeal).abs();
        return diffA.compareTo(diffB);
      });
    }

    return candidates.take(limit).map((item) {
      final kcal = item['energy'] as double;
      final leftAfter = (remaining - kcal).clamp(0.0, 9999.0);
      final pctOfRemaining = remaining > 0
          ? ((kcal / remaining) * 100).round()
          : 0;
      return {
        ...item,
        'fitReason':
            'ใช้ $pctOfRemaining% ของโควตาคงเหลือ • ทานแล้วจะเหลืออีก ${leftAfter.toStringAsFixed(0)} kcal',
      };
    }).toList();
  }

  double get averageLast7DaysCalories {
    double sum = 0.0;
    int activeDays = 0;
    for (int i = 0; i < 7; i++) {
      final d = selectedDate.subtract(Duration(days: i));
      final cal = caloriesForDate(d);
      if (cal > 0) {
        sum += cal;
        activeDays++;
      }
    }
    return activeDays > 0 ? (sum / activeDays) : 0.0;
  }

  double get totalDailyCalories => currentMeals.fold(
    0.0,
    (sum, item) => sum + ((item['calories'] as num?)?.toDouble() ?? 0.0),
  );

  double get previousDayCalories {
    final prevKey = dateKey(selectedDate.subtract(const Duration(days: 1)));
    final prevMeals = mealsByDate[prevKey] ?? [];
    return prevMeals.fold(
      0.0,
      (sum, item) => sum + ((item['calories'] as num?)?.toDouble() ?? 0.0),
    );
  }

  double? get currentBmi {
    if (weightKg <= 0 || heightCm <= 0) return null;
    final hMeter = heightCm / 100;
    return weightKg / (hMeter * hMeter);
  }

  int get age {
    if (birthDate == null) return 24;
    final now = DateTime.now();
    int a = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      a--;
    }
    return a.clamp(1, 120);
  }

  double calculateRecommendedTDEE({
    String? forGoal,
    String? forActivity,
    double? forWeight,
    double? forHeight,
    String? forGender,
  }) {
    final String actLevel = forActivity ?? activityLevel;
    final String gType = forGoal ?? goalType;
    final String gGender = forGender ?? gender;
    final double w = (forWeight != null && forWeight > 0)
        ? forWeight
        : (weightKg > 0 ? weightKg : 55.0);
    final double h = (forHeight != null && forHeight > 0)
        ? forHeight
        : (heightCm > 0 ? heightCm : 165.0);

    final double bmr = _calculateBmr(w, h, gGender);

    double multiplier = 1.375;
    if (actLevel.contains('น้อย')) multiplier = 1.2;
    if (actLevel.contains('ปานกลาง')) multiplier = 1.55;
    if (actLevel.contains('หนัก')) multiplier = 1.725;

    double tdee = bmr * multiplier;
    if (gType.contains('ลดน้ำหนัก')) tdee -= 400;
    if (gType.contains('เพิ่มน้ำหนัก')) tdee += 400;

    return tdee.clamp(1200, 4000).roundToDouble();
  }

  DynamicMap get intakeTrendInsight {
    final today = totalDailyCalories;
    final prev = previousDayCalories;
    final goal = dailyGoal;

    String trendTitle;
    String trendDetail;
    bool isMore = false;

    if (today == 0) {
      trendTitle = 'ยังไม่ได้บันทึกมื้ออาหารในวันนี้';
      trendDetail = 'กดปุ่มสแกนอาหารด้านล่างเพื่อเริ่มบันทึกมื้ออาหาร';
    } else if (prev > 0) {
      final diff = today - prev;
      if (diff.abs() < 50) {
        trendTitle = 'ปริมาณการกินใกล้เคียงเมื่อวาน';
        trendDetail =
            'วันนี้ทานไป ${today.toStringAsFixed(0)} kcal (เมื่อวาน ${prev.toStringAsFixed(0)} kcal)';
      } else if (diff > 0) {
        isMore = true;
        trendTitle =
            'วันนี้กินมากขึ้นกว่าเมื่อวาน +${diff.toStringAsFixed(0)} kcal';
        trendDetail =
            'ทานไปแล้ว ${today.toStringAsFixed(0)} kcal เทียบกับเมื่อวาน ${prev.toStringAsFixed(0)} kcal';
      } else {
        trendTitle =
            'วันนี้กินน้อยลงกว่าเมื่อวาน ${diff.abs().toStringAsFixed(0)} kcal';
        trendDetail =
            'ทานไปแล้ว ${today.toStringAsFixed(0)} kcal เทียบกับเมื่อวาน ${prev.toStringAsFixed(0)} kcal';
      }
    } else {
      final pct = goal > 0 ? ((today / goal) * 100).round() : 0;
      trendTitle = 'สะสมพลังงานแล้ว $pct% ของเป้าหมาย';
      trendDetail =
          'ทานไปแล้ว ${today.toStringAsFixed(0)} kcal จากเป้าหมาย ${goal.toStringAsFixed(0)} kcal';
    }

    String mealHighlight = '';
    if (currentMeals.isNotEmpty) {
      final latest = currentMeals.first;
      final mName = latest['name'] as String;
      final mCal = (latest['calories'] as num).toDouble();
      final sharePct = goal > 0 ? ((mCal / goal) * 100).round() : 0;
      if (mCal >= 550) {
        mealHighlight =
            'เมนู "$mName" (${mCal.toStringAsFixed(0)} kcal) คิดเป็น $sharePct% ของโควตาทั้งวัน ถือว่าพลังงานค่อนข้างสูง มื้อถัดไปควรเลือกเมนูเบาลง';
      } else if (mCal <= 350) {
        mealHighlight =
            'เมนู "$mName" (${mCal.toStringAsFixed(0)} kcal) คิดเป็น $sharePct% ของทั้งวัน เป็นมื้อที่กำลังดี ไม่หนักจนเกินไป';
      } else {
        mealHighlight =
            'เมนู "$mName" (${mCal.toStringAsFixed(0)} kcal) คิดเป็น $sharePct% ของเป้าหมายรายวัน อยู่ในระดับปานกลาง';
      }
    }

    return {
      'title': trendTitle,
      'detail': trendDetail,
      'mealHighlight': mealHighlight,
      'isMore': isMore,
    };
  }

  DynamicMap get goalAndChoiceInsight {
    final today = totalDailyCalories;
    final goal = dailyGoal;
    final remaining = goal - today;

    String statusType = 'normal';
    String suitabilityText;
    String foodChoiceAdvice;

    if (goalType.contains('ลดน้ำหนัก')) {
      if (today > goal) {
        statusType = 'danger';
        suitabilityText =
            'พลังงานเกินโควตาลดน้ำหนัก ${remaining.abs().toStringAsFixed(0)} kcal หากทานเกินต่อเนื่องจะทำให้น้ำหนักลดช้าลง';
        foodChoiceAdvice = 'วันนี้ทานเกินโควตาแล้ว แนะนำหยุดทานอาหารพลังงานสูง เน้นดื่มน้ำเปล่าหรือชาไม่หวาน';
      } else if (today > 0 && today < 1000 && currentMeals.length >= 2) {
        statusType = 'warning';
        suitabilityText = 'พลังงานยังน้อยเกินไปสำหรับเกณฑ์ลดน้ำหนักที่ปลอดภัย (ควรทานอย่างน้อย 1,200 kcal/วัน)';
        foodChoiceAdvice = 'ตอนนี้ยังทานน้อยไป แนะนำเลือกทานเมนูสุขภาพเพิ่ม เช่น สุกี้น้ำ อกไก่ย่าง หรือเกาเหลา';
      } else {
        statusType = 'normal';
        suitabilityText =
            'เหมาะสมกับเป้าหมายลดน้ำหนัก เหลือโควตาอีก ${remaining.toStringAsFixed(0)} kcal ในวันนี้';
        foodChoiceAdvice = remaining > 500
            ? 'ยังเหลือโควตาพอสมควร เลือกทานเมนูต้ม นึ่ง ยำ ที่ให้พลังงานเหมาะสมและอิ่มท้อง'
            : 'โควตาเหลือน้อยแล้ว มื้อถัดไปควรเลือกเมนูเบาๆ ไม่เกิน ${remaining.toStringAsFixed(0)} kcal';
      }
    } else if (goalType.contains('เพิ่มน้ำหนัก')) {
      if (today > goal + 400) {
        statusType = 'warning';
        suitabilityText =
            'พลังงานเกินเป้าหมายเพิ่มน้ำหนักไป ${remaining.abs().toStringAsFixed(0)} kcal อาจทำให้พลังงานสะสมเกินความจำเป็น';
        foodChoiceAdvice = 'มื้อถัดไปควรลดของทอดและน้ำหวาน หันมาเลือกอาหารมื้อหลักที่มีประโยชน์แทน';
      } else if (today < goal) {
        statusType = 'warning';
        suitabilityText =
            'พลังงานยังไม่ถึงเกณฑ์เพิ่มน้ำหนัก ขาดอีก ${remaining.toStringAsFixed(0)} kcal';
        foodChoiceAdvice = 'ยังทานน้อยไปสำหรับสายเพิ่มน้ำหนัก แนะนำเพิ่มมื้อว่างที่มีประโยชน์ เช่น นมถั่วเหลือง กล้วยหอม หรือไข่ต้ม';
      } else {
        statusType = 'normal';
        suitabilityText = 'ยอดเยี่ยม! พลังงานถึงเกณฑ์เพิ่มน้ำหนักอย่างเหมาะสม ช่วยเสริมสร้างร่างกายได้ดี';
        foodChoiceAdvice =
            'รักษาระดับการทานอาหารให้ครบมื้อและสม่ำเสมอในแต่ละวัน';
      }
    } else {
      if (today > goal + 150) {
        statusType = 'danger';
        suitabilityText =
            'พลังงานเกินเกณฑ์รักษาน้ำหนัก ${remaining.abs().toStringAsFixed(0)} kcal ควรควบคุมมื้อถัดไปให้สมดุล';
        foodChoiceAdvice = 'เลือกทานเมนูแคลอรี่ต่ำ เน้นผักและอาหารไม่มันเพื่อชดเชยพลังงานส่วนเกิน';
      } else {
        statusType = 'normal';
        suitabilityText =
            'สมดุลดีมาก เหมาะสมกับการรักษาน้ำหนักคงที่ เหลืออีก ${remaining.clamp(0, 9999).toStringAsFixed(0)} kcal';
        foodChoiceAdvice =
            'เลือกทานอาหารให้หลากหลาย ลดหวานมันเค็ม เพื่อรักษาสมดุลร่างกาย';
      }
    }

    return {
      'status': statusType,
      'suitability': suitabilityText,
      'choiceAdvice': foodChoiceAdvice,
      'remaining': remaining,
    };
  }

  void setSelectedDate(DateTime date) {
    selectedDate = date;
    notifyListeners();
  }

  Future<void> logMeal({
    required String name,
    required double calories,
    int? weightGrams,
    String mealType = 'มื้ออาหาร',
    TimeOfDay? customTime,
    DateTime? targetDate,
  }) async {
    final t = customTime ?? TimeOfDay.now();
    final timeStr =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final key = dateKey(targetDate ?? selectedDate);

    mealsByDate.putIfAbsent(key, () => []);
    mealsByDate[key]!.insert(0, {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'name': name,
      'calories': calories,
      'weightGrams': weightGrams ?? 300,
      'mealType': mealType,
      'time': timeStr,
    });
    await _persistCurrentAccount();
    notifyListeners();
  }

  Future<void> deleteMeal(String id, {String? fromDateKey}) async {
    final key = fromDateKey ?? dateKey(selectedDate);
    mealsByDate[key]?.removeWhere((m) => m['id'] == id);
    if (mealsByDate[key]?.isEmpty ?? false) {
      mealsByDate.remove(key);
    }
    await _persistCurrentAccount();
    notifyListeners();
  }

  List<StringMap> get adminFoods =>
      foods.where((f) => f['source'] == 'admin').toList();

  void addFood(StringMap foodData) {
    foods.insert(0, {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      ...foodData,
    });
    notifyListeners();
  }

  void deleteFoodByItem(StringMap item) {
    foods.remove(item);
    notifyListeners();
  }

  void updateUser(String id, StringMap data) {
    if (users.containsKey(id)) {
      users[id]!.addAll(data);
      notifyListeners();
    }
  }

  void deleteUser(String id) {
    users.remove(id);
    notifyListeners();
  }
}

// ───────────────────────── Root App ─────────────────────────
class NutritionStartupApp extends StatelessWidget {
  const NutritionStartupApp({super.key, required this.initialization});

  final Future<AuthService> initialization;

  @override
  Widget build(BuildContext context) => FutureBuilder<AuthService>(
    future: initialization,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return NutritionApp(authService: snapshot.requireData);
      }
      if (snapshot.hasError) {
        final startupError = snapshot.error;
        final details = startupError is StateError
            ? startupError.message
            : startupError?.runtimeType.toString() ?? 'ไม่ทราบสาเหตุ';
        return MaterialApp(
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'เริ่มต้น Supabase ไม่สำเร็จ\n$details',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        );
      }
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator(color: kGreen)),
        ),
      );
    },
  );
}

class NutritionApp extends StatefulWidget {
  const NutritionApp({super.key, required this.authService});

  final AuthService authService;

  @override
  State<NutritionApp> createState() => _NutritionAppState();
}

class _NutritionAppState extends State<NutritionApp> {
  final _auth = AdminAuth();
  late final AppContent _content;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _content = AppContent(authService: widget.authService);
    _initialization = _content.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('เปิดข้อมูลบัญชีไม่สำเร็จ: ${snapshot.error}'),
                ),
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator(color: kGreen)),
            ),
          );
        }
        return ListenableBuilder(
          listenable: Listenable.merge([_auth, _content]),
          builder: (context, _) => _Providers(
            auth: _auth,
            content: _content,
            child: MaterialApp(
              title: 'วิเคราะห์โภชนาการ',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                scaffoldBackgroundColor: Colors.white,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: kGreen,
                  primary: kGreen,
                ),
                useMaterial3: true,
              ),
              initialRoute: _content.isLoggedIn ? '/home' : '/',
              routes: {
                '/': (_) => const IntroScreen(),
                '/register': (_) => const RegisterScreen(),
                '/dob': (_) => const DobScreen(),
                '/health': (_) => const HealthScreen(),
                '/goal': (_) => const GoalScreen(),
                '/home': (_) => const DashboardScreen(),
                '/insights': (_) => const InsightsScreen(),
                '/stats': (_) => const StatsScreen(),
                '/history': (_) => const MealHistoryScreen(),
                '/capture': (_) => const CaptureScreen(),
                '/analysis': (_) => const AnalysisScreen(),
                '/profile': (_) => const ProfileScreen(),
                '/change_password': (_) => const ChangePasswordScreen(),
                '/account': (_) => const AccountScreen(),
                '/admin/home': (_) => const AdminHomeScreen(),
                '/admin/users': (_) => const AdminUsersScreen(),
                '/admin/users/edit': (_) => const AdminEditUserScreen(),
                '/admin/foods': (_) => const AdminFoodsScreen(),
                '/admin/foods/add': (_) => const AdminAddFoodScreen(),
              },
            ),
          ),
        );
      },
    );
  }
}

// ───────────────────────── InheritedWidget Providers ─────────────────────────
class _Providers extends InheritedWidget {
  final AdminAuth auth;
  final AppContent content;
  const _Providers({
    required this.auth,
    required this.content,
    required super.child,
  });

  static _Providers of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Providers>()!;

  @override
  bool updateShouldNotify(_Providers old) => true;
}

extension ProviderAccess on BuildContext {
  AdminAuth get auth => _Providers.of(this).auth;
  AppContent get content => _Providers.of(this).content;
  bool get isAdmin => _Providers.of(this).auth.isAdmin;
}

// ───────────────────────── Shared Modern Widgets ─────────────────────────
class CleanAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBack;
  final List<Widget>? actions;
  const CleanAppBar({
    super.key,
    this.title = '',
    this.showBack = true,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: kInk,
          letterSpacing: -0.3,
        ),
      ),
      actions: actions,
      leading: showBack
          ? Padding(
              padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
              child: InkWell(
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kBorder, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: kInk.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 15,
                    color: kInk,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(60);
}

class OnboardingStepHeader extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final String stepTitle;
  const OnboardingStepHeader({
    super.key,
    required this.currentStep,
    this.totalSteps = 4,
    required this.stepTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ขั้นตอนที่ $currentStep จาก $totalSteps',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kGreenDark,
              ),
            ),
            Text(
              stepTitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: currentStep / totalSteps,
            minHeight: 6,
            backgroundColor: kGreenBg,
            color: kGreen,
          ),
        ),
      ],
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color color;
  final Color textColor;
  final IconData? icon;
  const PrimaryButton(
    this.text,
    this.onTap, {
    super.key,
    this.color = kGreen,
    this.textColor = Colors.white,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: color == kGreen
            ? [
                BoxShadow(
                  color: kGreen.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: textColor),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CleanTextField extends StatefulWidget {
  final String hint;
  final IconData? icon;
  final IconData? suffixIcon;
  final bool obscure;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  const CleanTextField({
    super.key,
    required this.hint,
    this.icon,
    this.suffixIcon,
    this.obscure = false,
    this.controller,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
  });

  @override
  State<CleanTextField> createState() => _CleanTextFieldState();
}

class _CleanTextFieldState extends State<CleanTextField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscure;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'วิเคราะห์แคลอรี่จากรูปอาหาร',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const _Root(),
    );
  }
}

/// เลือกหน้าตามสถานะ: ยังไม่ล็อกอิน → แอดมิน → ข้อมูลยังไม่ครบ → หน้าหลัก
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: -6),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 14, color: kRed),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: kRed,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Modern Bottom Nav (5 Slots) ─────────────────────────
class BaseNavLayout extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  const BaseNavLayout({
    super.key,
    required this.body,
    required this.currentIndex,
  });

  void _navigate(BuildContext context, int index) {
    if (index == currentIndex) return;
    if (index == 0) Navigator.pushReplacementNamed(context, '/home');
    if (index == 1) Navigator.pushReplacementNamed(context, '/insights');
    if (index == 2) Navigator.pushReplacementNamed(context, '/capture');
    if (index == 3) Navigator.pushReplacementNamed(context, '/history');
    if (index == 4) Navigator.pushReplacementNamed(context, '/profile');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: body),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: kBorder, width: 1.5)),
          boxShadow: [
            BoxShadow(
              color: kInk.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.dashboard_rounded,
                label: 'หน้าหลัก',
                selected: currentIndex == 0,
                onTap: () => _navigate(context, 0),
              ),
              _NavItem(
                icon: Icons.insights_rounded,
                label: 'วิเคราะห์',
                selected: currentIndex == 1,
                onTap: () => _navigate(context, 1),
              ),
              InkWell(
                onTap: () => _navigate(context, 2),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: kGreen,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: kGreen.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'สแกน',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _NavItem(
                icon: Icons.history_rounded,
                label: 'ประวัติ',
                selected: currentIndex == 3,
                onTap: () => _navigate(context, 3),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'โปรไฟล์',
                selected: currentIndex == 4,
                onTap: () => _navigate(context, 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? kGreen : kMuted, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? kGreenDark : kMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> showAdminLoginDialog(BuildContext context) async {
  final emailCtrl = TextEditingController(text: 'admin@nutrition.app');
  final passCtrl = TextEditingController();
  var error = '';

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: kGreen),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'เข้าสู่ระบบผู้ดูแลระบบ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: kInk,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: emailCtrl,
              decoration: InputDecoration(
                labelText: 'อีเมลแอดมิน',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'รหัสผ่าน (อย่างน้อย 4 ตัวอักษร)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            if (error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                error,
                style: const TextStyle(
                  color: kRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: kMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final auth = _Providers.of(context).auth;
              if (auth.login(emailCtrl.text.trim(), passCtrl.text)) {
                Navigator.pop(ctx, true);
              } else {
                setState(
                  () => error = 'กรุณากรอกอีเมลและรหัสผ่านอย่างน้อย 4 ตัวอักษร',
                );
              }
            },
            child: const Text(
              'เข้าสู่ระบบ',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

// ───────────────────────── 1. Login / Intro ─────────────────────────
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกอีเมลและรหัสผ่าน'),
          backgroundColor: kRed,
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final success = await context.content.login(
        _emailCtrl.text,
        _passCtrl.text,
      );
      if (!mounted) return;
      if (success) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('อีเมลหรือรหัสผ่านไม่ถูกต้อง'),
            backgroundColor: kRed,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เข้าสู่ระบบไม่สำเร็จ: $error'),
          backgroundColor: kRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: kGreenBg,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: kGreen.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  size: 48,
                  color: kGreen,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'วิเคราะห์โภชนาการ',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: kInk,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'สแกนอาหารด้วย AI คำนวณแคลอรี่อัตโนมัติ\nพร้อมแนะนำมื้อถัดไปให้เหมาะกับเป้าหมายของคุณ',
                style: TextStyle(color: kMuted, fontSize: 14, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              CleanTextField(
                hint: 'อีเมล',
                icon: Icons.email_outlined,
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
              ),
              CleanTextField(
                hint: 'รหัสผ่าน',
                icon: Icons.lock_outline,
                obscure: true,
                controller: _passCtrl,
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                _isSubmitting ? 'กำลังเข้าสู่ระบบ...' : 'เข้าสู่ระบบ',
                _isSubmitting ? () {} : _login,
                icon: Icons.login_rounded,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'ยังไม่มีบัญชีใช่ไหม?',
                    style: TextStyle(color: kMuted, fontSize: 13),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/register'),
                    child: const Text(
                      'สมัครสมาชิกใหม่',
                      style: TextStyle(
                        color: kGreenDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: kBorder, height: 24),
              TextButton.icon(
                onPressed: () async {
                  final ok = await showAdminLoginDialog(context);
                  if (ok && context.mounted) {
                    Navigator.pushReplacementNamed(context, '/admin/home');
                  }
                },
                icon: const Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 18,
                  color: kGreenDark,
                ),
                label: const Text(
                  'เข้าสู่ระบบสำหรับผู้ดูแลระบบ (Admin)',
                  style: TextStyle(
                    color: kGreenDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 2. Register ─────────────────────────
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String? _nameError;
  String? _emailError;
  String? _passwordError;

  static final RegExp _emailRegex = RegExp(r'^[\w\.\+\-]+@[\w\-]+\.[\w\.\-]+$');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    setState(() {
      _nameError = name.isEmpty ? 'กรุณากรอกชื่อ - นามสกุล' : null;
      _emailError = email.isEmpty
          ? 'กรุณากรอกอีเมล'
          : (!_emailRegex.hasMatch(email)
                ? 'รูปแบบอีเมลไม่ถูกต้อง เช่น name@example.com'
                : null);
      _passwordError = password.isEmpty
          ? 'กรุณากรอกรหัสผ่าน'
          : (password.length < 8 ? 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร' : null);
    });

    return _nameError == null && _emailError == null && _passwordError == null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CleanAppBar(title: 'สมัครสมาชิก'),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const OnboardingStepHeader(
              currentStep: 1,
              stepTitle: 'สร้างบัญชีผู้ใช้',
            ),
            const SizedBox(height: 24),
            const Text(
              'เริ่มต้นดูแลโภชนาการของคุณ',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: kInk,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'กรอกข้อมูลพื้นฐานเพื่อสร้างบัญชีผู้ใช้งาน',
              style: TextStyle(color: kMuted, fontSize: 13),
            ),
            const SizedBox(height: 24),
            CleanTextField(
              hint: 'ชื่อ - นามสกุล',
              icon: Icons.person_outline,
              controller: _nameCtrl,
            ),
            if (_nameError != null) FieldError(_nameError!),
            CleanTextField(
              hint: 'อีเมล',
              icon: Icons.email_outlined,
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
            ),
            if (_emailError != null) FieldError(_emailError!),
            CleanTextField(
              hint: 'รหัสผ่าน (อย่างน้อย 8 ตัวอักษร)',
              icon: Icons.lock_outline,
              controller: _passwordCtrl,
              obscure: true,
            ),
            if (_passwordError != null) FieldError(_passwordError!),
            const Spacer(),
            PrimaryButton('ถัดไป', () {
              if (!_validate()) return;
              final started = context.content.startNewAccount(
                name: _nameCtrl.text.trim(),
                newEmail: _emailCtrl.text.trim(),
                password: _passwordCtrl.text,
              );
              if (!started) {
                setState(
                  () =>
                      _emailError = 'อีเมลนี้มีบัญชีอยู่แล้ว กรุณาเข้าสู่ระบบ',
                );
                return;
              }
              Navigator.pushNamed(context, '/dob');
            }),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── 2.5 Date of Birth ─────────────────────────
class DobScreen extends StatefulWidget {
  const DobScreen({super.key});
  @override
  State<DobScreen> createState() => _DobScreenState();
}

class _DobScreenState extends State<DobScreen> {
  static const _months = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];

  late DateTime _selectedDate;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _selectedDate = context.content.birthDate ?? DateTime(2000, 1, 1);
      _initialized = true;
    }
  }

  int get _calculatedAge {
    final now = DateTime.now();
    int a = now.year - _selectedDate.year;
    if (now.month < _selectedDate.month ||
        (now.month == _selectedDate.month && now.day < _selectedDate.day)) {
      a--;
    }
    return a.clamp(1, 120);
  }

  void _changeYearOrMonth({int? newYear, int? newMonth}) {
    final y = newYear ?? _selectedDate.year;
    final m = newMonth ?? _selectedDate.month;
    final maxDay = DateTime(y, m + 1, 0).day;
    final d = _selectedDate.day > maxDay ? maxDay : _selectedDate.day;
    final candidate = DateTime(y, m, d);
    final now = DateTime.now();
    setState(() {
      _selectedDate = candidate.isAfter(now)
          ? DateTime(now.year, now.month, now.day)
          : candidate;
    });
  }

  Future<void> _next() async {
    final now = DateTime.now();
    if (_selectedDate.isAfter(DateTime(now.year, now.month, now.day))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('วันเกิดต้องไม่เป็นวันที่ในอนาคต'),
          backgroundColor: kRed,
        ),
      );
      return;
    }
    final content = context.content;
    await content.updateAccountInfo(newBirthDate: _selectedDate);
    if (!mounted) return;
    Navigator.pushNamed(context, '/health');
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = List.generate(currentYear - 1920 + 1, (i) => currentYear - i);

    return Scaffold(
      appBar: const CleanAppBar(title: 'วันเดือนปีเกิด'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                children: [
                  const OnboardingStepHeader(
                    currentStep: 2,
                    stepTitle: 'ข้อมูลอายุ',
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'เลือกวันเดือนปีเกิดของคุณ',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: kInk,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'ใช้ปฏิทินด้านล่างเพื่อเลือกวันเกิด ระบบจะคำนวณอายุและอัตราการเผาผลาญให้อัตโนมัติ',
                    style: TextStyle(fontSize: 13, color: kMuted),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kGreenBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kGreen.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.cake_rounded,
                            color: kGreenDark,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'วันเกิดที่เลือก',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: kMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_selectedDate.day} ${_months[_selectedDate.month - 1]} ${_selectedDate.year} (พ.ศ. ${_selectedDate.year + 543})',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: kInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: kGreen,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'อายุ $_calculatedAge ปี',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: kBorder, width: 1.5),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedDate.month,
                              isExpanded: true,
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                color: kGreen,
                              ),
                              items: List.generate(12, (idx) {
                                return DropdownMenuItem(
                                  value: idx + 1,
                                  child: Text(
                                    _months[idx],
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: kInk,
                                    ),
                                  ),
                                );
                              }),
                              onChanged: (m) {
                                if (m != null) _changeYearOrMonth(newMonth: m);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: kBorder, width: 1.5),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedDate.year,
                              isExpanded: true,
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                color: kGreen,
                              ),
                              items: years.map((y) {
                                return DropdownMenuItem(
                                  value: y,
                                  child: Text(
                                    'ค.ศ. $y',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: kInk,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (y) {
                                if (y != null) _changeYearOrMonth(newYear: y);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: kBorder, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: kInk.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: kGreen,
                          onPrimary: Colors.white,
                          onSurface: kInk,
                        ),
                      ),
                      child: CalendarDatePicker(
                        key: ValueKey(
                          '${_selectedDate.year}-${_selectedDate.month}',
                        ),
                        initialDate: _selectedDate,
                        firstDate: DateTime(1920),
                        lastDate: DateTime.now(),
                        onDateChanged: (picked) {
                          setState(() => _selectedDate = picked);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: PrimaryButton('ถัดไป', _next),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── 3. Health & Goal Information ─────────────────────────
class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  String _selectedGender = 'หญิง';
  String _selectedTarget = 'ลดน้ำหนัก';
  String _selectedActivity = 'ปานกลาง (ออกกำลังกายสม่ำเสมอ)';
  String? _weightError;
  String? _heightError;
  bool _initialized = false;
  bool _fromProfile = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['fromProfile'] == true) {
        _fromProfile = true;
      }
      _selectedGender = context.content.gender;
      _selectedTarget = context.content.goalType;
      _selectedActivity = context.content.activityLevel;
      _weightCtrl.text = context.content.weightKg > 0
          ? context.content.weightKg.toStringAsFixed(1)
          : '';
      _heightCtrl.text = context.content.heightCm > 0
          ? context.content.heightCm.toStringAsFixed(0)
          : '';
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  double? get _bmi {
    final w = double.tryParse(_weightCtrl.text.trim());
    final h = double.tryParse(_heightCtrl.text.trim());
    if (w == null || h == null || w < 20 || w > 300 || h < 80 || h > 250) {
      return null;
    }
    final hMeter = h / 100;
    return w / (hMeter * hMeter);
  }

  Map<String, dynamic> _bmiStatus(double bmi) {
    if (bmi < 18.5) {
      return {'label': 'น้ำหนักน้อย / ผอม', 'color': kBlue, 'bg': kGreenBg};
    } else if (bmi < 23.0) {
      return {
        'label': 'สมส่วน (สุขภาพดี)',
        'color': kGreenDark,
        'bg': kGreenBg,
      };
    } else if (bmi < 25.0) {
      return {'label': 'น้ำหนักเกิน (ท้วม)', 'color': kOrange, 'bg': kGreenBg};
    } else {
      return {'label': 'โรคอ้วน (ควรควบคุม)', 'color': kRed, 'bg': kRedBg};
    }
  }

  Future<void> _onContinue() async {
    final w = double.tryParse(_weightCtrl.text.trim());
    final h = double.tryParse(_heightCtrl.text.trim());

    setState(() {
      _weightError = (w == null || w < 20 || w > 300)
          ? 'กรุณากรอกน้ำหนักระหว่าง 20 - 300 กิโลกรัม'
          : null;
      _heightError = (h == null || h < 80 || h > 250)
          ? 'กรุณากรอกส่วนสูงระหว่าง 80 - 250 เซนติเมตร'
          : null;
    });

    if (_weightError != null || _heightError != null) return;

    final content = context.content;
    try {
      await content.updateHealthProfile(
        userGender: _selectedGender,
        weight: w!,
        height: h!,
        targetType: _fromProfile ? _selectedTarget : null,
        activity: _fromProfile ? _selectedActivity : null,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('บันทึกข้อมูลสุขภาพไม่สำเร็จ: $error'),
            backgroundColor: kRed,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    if (_fromProfile) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'บันทึกข้อมูลสุขภาพและเป้าหมาย "$_selectedTarget" (${content.dailyGoal.toStringAsFixed(0)} kcal/วัน) เรียบร้อยแล้ว',
          ),
          backgroundColor: kGreen,
        ),
      );
      Navigator.pop(context);
    } else {
      Navigator.pushNamed(context, '/goal');
    }
  }

  Widget _genderOption(String label, IconData icon) {
    final isSelected = _selectedGender == label;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedGender = label),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? kGreenBg : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? kGreen : kBorder,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: isSelected ? kGreenDark : kMuted),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? kGreenDark : kMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final birthDate = context.content.birthDate;
    final birthDateLabel = birthDate == null
        ? 'ยังไม่ได้ระบุวันเกิด'
        : '${birthDate.day}/${birthDate.month}/${birthDate.year} (อายุ ${context.content.age} ปี)';

    final currentBmi = _bmi;
    final liveRecommendedKcal = context.content.calculateRecommendedTDEE(
      forGoal: _selectedTarget,
      forActivity: _selectedActivity,
      forWeight: double.tryParse(_weightCtrl.text.trim()),
      forHeight: double.tryParse(_heightCtrl.text.trim()),
      forGender: _selectedGender,
    );

    return Scaffold(
      appBar: CleanAppBar(
        title: _fromProfile ? 'ข้อมูลสุขภาพและเป้าหมาย' : 'ข้อมูลสุขภาพ',
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    if (!_fromProfile) ...[
                      const OnboardingStepHeader(
                        currentStep: 3,
                        stepTitle: 'สัดส่วนร่างกาย',
                      ),
                      const SizedBox(height: 20),
                    ],
                    Text(
                      _fromProfile
                          ? 'จัดการข้อมูลสุขภาพและเป้าหมาย'
                          : 'ข้อมูลสุขภาพของคุณ',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'ใช้คำนวณค่าดัชนีมวลกาย (BMI) และพลังงานที่เหมาะสมในแต่ละวัน',
                      style: TextStyle(color: kMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: kGreenBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.cake_outlined,
                            size: 18,
                            color: kGreenDark,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'วันเกิด: $birthDateLabel',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: kInk,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'เพศ',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _genderOption('ชาย', Icons.male),
                        const SizedBox(width: 12),
                        _genderOption('หญิง', Icons.female),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'น้ำหนัก (กก.)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: kInk,
                                ),
                              ),
                              const SizedBox(height: 8),
                              CleanTextField(
                                hint: 'เช่น 55.0',
                                icon: Icons.monitor_weight_outlined,
                                controller: _weightCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                ],
                                onChanged: (_) =>
                                    setState(() => _weightError = null),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ส่วนสูง (ซม.)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: kInk,
                                ),
                              ),
                              const SizedBox(height: 8),
                              CleanTextField(
                                hint: 'เช่น 165',
                                icon: Icons.height,
                                controller: _heightCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                ],
                                onChanged: (_) =>
                                    setState(() => _heightError = null),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_weightError != null) FieldError(_weightError!),
                    if (_heightError != null) FieldError(_heightError!),
                    if (currentBmi != null) ...[
                      Builder(
                        builder: (context) {
                          final status = _bmiStatus(currentBmi);
                          final Color statusColor = status['color'] as Color;
                          final Color statusBg = status['bg'] as Color;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'ดัชนีมวลกาย (BMI)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: kMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      currentBmi.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: kInk,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    status['label'] as String,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                    if (_fromProfile) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Divider(
                          color: kBorder,
                          height: 1,
                          thickness: 1.5,
                        ),
                      ),
                      GoalSelectorSection(
                        selectedTarget: _selectedTarget,
                        selectedActivity: _selectedActivity,
                        recommendedKcal: liveRecommendedKcal,
                        onTargetChanged: (val) =>
                            setState(() => _selectedTarget = val),
                        onActivityChanged: (val) =>
                            setState(() => _selectedActivity = val),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                _fromProfile ? 'บันทึกข้อมูลสุขภาพและเป้าหมาย' : 'ถัดไป',
                _onContinue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Shared Goal Selector Section ─────────────────────────
class GoalSelectorSection extends StatelessWidget {
  final String selectedTarget;
  final String selectedActivity;
  final double recommendedKcal;
  final ValueChanged<String> onTargetChanged;
  final ValueChanged<String> onActivityChanged;

  const GoalSelectorSection({
    super.key,
    required this.selectedTarget,
    required this.selectedActivity,
    required this.recommendedKcal,
    required this.onTargetChanged,
    required this.onActivityChanged,
  });

  static const List<DynamicMap> targetCards = [
    {
      'title': 'ลดน้ำหนัก',
      'subtitle': 'ปรับลดพลังงาน -400 kcal/วัน เพื่อควบคุมน้ำหนักอย่างปลอดภัย',
      'icon': Icons.trending_down_rounded,
    },
    {
      'title': 'รักษาน้ำหนัก',
      'subtitle': 'ทานพลังงานให้สมดุลกับกิจกรรม เพื่อรักษาสุขภาพคงที่',
      'icon': Icons.balance_rounded,
    },
    {
      'title': 'เพิ่มน้ำหนัก',
      'subtitle':
          'เพิ่มพลังงาน +400 kcal/วัน เพื่อเสริมสร้างมวลกายอย่างเหมาะสม',
      'icon': Icons.trending_up_rounded,
    },
  ];

  static const List<String> activityOptions = [
    'น้อย (ไม่ออกกำลังกาย)',
    'ปานกลาง (ออกกำลังกายสม่ำเสมอ)',
    'หนัก (ออกกำลังกายหนักทุกวัน)',
  ];

  @override
  Widget build(BuildContext context) {
    final activeActivity = activityOptions.contains(selectedActivity)
        ? selectedActivity
        : activityOptions[1];
    final activityDetails = <String, String>{
      activityOptions[0]: 'ใช้ชีวิตประจำวันทั่วไป ไม่ค่อยได้ออกกำลังกาย',
      activityOptions[1]: 'ออกกำลังกายหรือเคลื่อนไหวร่างกายสม่ำเสมอ',
      activityOptions[2]: 'ออกกำลังกายหนักหรือใช้แรงมากเกือบทุกวัน',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'เป้าหมายสุขภาพ',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: kInk,
          ),
        ),
        const SizedBox(height: 10),
        ...targetCards.map((item) {
          final title = item['title'] as String;
          final isSelected = selectedTarget == title;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => onTargetChanged(title),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? kGreenBg : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? kGreen : kBorder,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? kGreen : Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: isSelected ? Colors.white : kMuted,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: isSelected ? kGreenDark : kInk,
                            ),
                          ),
                          Text(
                            item['subtitle'] as String,
                            style: const TextStyle(fontSize: 11, color: kMuted),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: kGreen,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        const Text(
          'ระดับกิจกรรมประจำวัน',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: kInk,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kBorder, width: 1.5),
          ),
          child: Column(
            children: activityOptions.map((item) {
              final isSelected = activeActivity == item;
              final title = item.split(' (').first;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () => onActivityChanged(item),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? kGreenBg : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isSelected ? kGreen : kBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item == activityOptions[0]
                              ? Icons.directions_walk_rounded
                              : item == activityOptions[1]
                              ? Icons.directions_run_rounded
                              : Icons.fitness_center_rounded,
                          size: 20,
                          color: isSelected ? kGreenDark : kMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? kGreenDark : kInk,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                activityDetails[item]!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: kMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: kGreen,
                            size: 19,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: kGreenBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kGreen.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'เป้าหมาย ($selectedTarget)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: kInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    'พลังงานที่แนะนำต่อวัน',
                    style: TextStyle(fontSize: 11, color: kMuted),
                  ),
                ],
              ),
              Text(
                '${recommendedKcal.toStringAsFixed(0)} kcal/วัน',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: kGreenDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── 4. Goals (Onboarding Step 4) ─────────────────────────
class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key});
  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  String _selectedTarget = 'ลดน้ำหนัก';
  String _selectedActivity = 'ปานกลาง (ออกกำลังกายสม่ำเสมอ)';
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _selectedTarget = context.content.goalType;
      _selectedActivity = context.content.activityLevel;
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final calculatedGoal = context.content.calculateRecommendedTDEE(
      forGoal: _selectedTarget,
      forActivity: _selectedActivity,
    );

    return Scaffold(
      appBar: const CleanAppBar(title: 'เป้าหมายของคุณ'),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  const OnboardingStepHeader(
                    currentStep: 4,
                    stepTitle: 'ตั้งเป้าหมายแคลอรี่',
                  ),
                  const SizedBox(height: 20),
                  GoalSelectorSection(
                    selectedTarget: _selectedTarget,
                    selectedActivity: _selectedActivity,
                    recommendedKcal: calculatedGoal,
                    onTargetChanged: (val) =>
                        setState(() => _selectedTarget = val),
                    onActivityChanged: (val) =>
                        setState(() => _selectedActivity = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton('บันทึกและเริ่มต้นใช้งาน', () async {
              final content = context.content;
              try {
                await content.updateHealthProfile(
                  targetType: _selectedTarget,
                  activity: _selectedActivity,
                );
                final hasSession = await content.completeRegistration();
                if (context.mounted && hasSession) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/home',
                    (_) => false,
                  );
                } else if (context.mounted) {
                  await showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('สมัครสมาชิกสำเร็จ'),
                      content: const Text(
                        'กรุณายืนยันอีเมลจากกล่องข้อความก่อนเข้าสู่ระบบ',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('ตกลง'),
                        ),
                      ],
                    ),
                  );
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/',
                      (_) => false,
                    );
                  }
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('สมัครสมาชิกไม่สำเร็จ: $error'),
                      backgroundColor: kRed,
                    ),
                  );
                }
              }
            }),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Shared Next-Meal Recommendation Card ─────────────────────────
class NextMealRecommendationCard extends StatelessWidget {
  final String nextMealLabel;
  final double remainingQuota;
  final List<DynamicMap> recommendedMeals;
  final bool allowQuickLog;
  final void Function(DynamicMap meal)? onQuickLog;

  const NextMealRecommendationCard({
    super.key,
    required this.nextMealLabel,
    required this.remainingQuota,
    required this.recommendedMeals,
    this.allowQuickLog = false,
    this.onQuickLog,
  });

  @override
  Widget build(BuildContext context) {
    final isQuotaFull = remainingQuota <= 80;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isQuotaFull
              ? kRed.withValues(alpha: 0.35)
              : kGreen.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isQuotaFull ? kRed : kGreen).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: isQuotaFull ? kRedBg : kGreenBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isQuotaFull
                      ? Icons.no_meals_rounded
                      : Icons.auto_awesome_rounded,
                  size: 19,
                  color: isQuotaFull ? kRed : kGreenDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isQuotaFull
                          ? 'โควตาพลังงานวันนี้เต็มแล้ว'
                          : 'แนะนำเมนูสำหรับ$nextMealLabel',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isQuotaFull
                          ? 'ควรเลือกดื่มน้ำเปล่าหรือทานผลไม้แคลอรี่ต่ำแทนมื้อหนัก'
                          : 'คัดเมนูจากฐานข้อมูลที่พลังงานไม่เกินโควตาคงเหลือ (${remainingQuota.toStringAsFixed(0)} kcal)',
                      style: const TextStyle(fontSize: 11, color: kMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(recommendedMeals.length, (idx) {
            final item = recommendedMeals[idx];
            final kcal = (item['energy'] as num).toDouble();
            final isLast = idx == recommendedMeals.length - 1;

            return Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isQuotaFull ? kRedBg : kGreenBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.restaurant_menu_rounded,
                      color: isQuotaFull ? kRed : kGreenDark,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] as String,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: kInk,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${kcal.toStringAsFixed(0)} kcal • ${item['serving']}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isQuotaFull ? kRed : kGreenDark,
                          ),
                        ),
                        if (item['fitReason'] != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            item['fitReason'] as String,
                            style: const TextStyle(fontSize: 10, color: kMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (allowQuickLog && kcal > 0 && onQuickLog != null) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => onQuickLog!(item),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: kGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                            SizedBox(width: 2),
                            Text(
                              'บันทึก',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ───────────────────────── 5. Home Dashboard ─────────────────────────
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _formatDateLabel(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'วันนี้';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (d.year == yesterday.year &&
        d.month == yesterday.month &&
        d.day == yesterday.day) {
      return 'เมื่อวาน';
    }
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.content;
    final totalCal = c.totalDailyCalories;
    final goalCal = c.dailyGoal;
    final percent = goalCal > 0 ? ((totalCal / goalCal) * 100).round() : 0;
    final progress = goalCal > 0 ? (totalCal / goalCal).clamp(0.0, 1.0) : 0.0;
    final isOver = totalCal > goalCal;
    final isGoalReached =
        !isOver && goalCal > 0 && (goalCal - totalCal).abs() < 1;
    final remainingCal = (goalCal - totalCal).abs();
    final meals = c.currentMeals;

    final bmi = c.currentBmi;

    return BaseNavLayout(
      currentIndex: 0,
      body: RefreshIndicator(
        color: kGreen,
        onRefresh: () async =>
            Future.delayed(const Duration(milliseconds: 500)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'สวัสดี, ${c.fullName.split(' ').first}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: kInk,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          InkWell(
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/health',
                              arguments: {'fromProfile': true},
                            ),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: kGreenBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'เป้าหมาย: ${c.goalType}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: kGreenDark,
                                ),
                              ),
                            ),
                          ),
                          if (bmi != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '• BMI ${bmi.toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: kMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: c.selectedDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null && context.mounted) {
                      c.setSelectedDate(picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kBorder, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: kGreenDark,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatDateLabel(c.selectedDate),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: kInk,
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          size: 16,
                          color: kMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── Hero Calorie Dashboard Card ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isOver
                      ? kRed.withValues(alpha: 0.4)
                      : kGreen.withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isOver ? kRed : kGreen).withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'พลังงานวันนี้',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: kInk,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'คงเหลือ = เป้าหมาย - พลังงานที่รับประทาน',
                          style: TextStyle(fontSize: 11, color: kMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      SizedBox(
                        width: 124,
                        height: 124,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 124,
                              height: 124,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 12,
                                strokeCap: StrokeCap.round,
                                backgroundColor: isOver ? kRedBg : kGreenBg,
                                color: isOver
                                    ? kRed
                                    : (isGoalReached ? kGreenDark : kGreen),
                              ),
                            ),
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isOver ? kRedBg : kGreenBg,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    isOver ? 'เกินเป้า' : 'คงเหลือ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isOver ? kRed : kGreenDark,
                                    ),
                                  ),
                                  Text(
                                    remainingCal.toStringAsFixed(0),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: kInk,
                                    ),
                                  ),
                                  const Text(
                                    'kcal',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: kMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _MetricMiniRow(
                              label: 'เป้าหมายรายวัน',
                              value: '${goalCal.toStringAsFixed(0)} kcal',
                              valueColor: kInk,
                            ),
                            const SizedBox(height: 4),
                            _MetricMiniRow(
                              label: 'รับประทานแล้ว',
                              value: '${totalCal.toStringAsFixed(0)} kcal',
                              valueColor: kInk,
                            ),
                            const SizedBox(height: 4),
                            _MetricMiniRow(
                              label: 'เป้าหมายที่ใช้ไป',
                              value: '$percent%',
                              valueColor: isOver ? kRed : kGreenDark,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DashboardBaselineCard(content: c),
                  const SizedBox(height: 16),
                  const Divider(color: kBorder, height: 1),
                  const SizedBox(height: 12),
                  MealCalorieColorBar(
                    breakfastCal: c.caloriesByMealType('มื้อเช้า'),
                    lunchCal: c.caloriesByMealType('มื้อกลางวัน'),
                    dinnerCal: c.caloriesByMealType('มื้อเย็น'),
                    snackCal: c.caloriesByMealType('มื้อว่าง'),
                    compact: true,
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () =>
                        Navigator.pushReplacementNamed(context, '/stats'),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: kGreenBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bar_chart_rounded,
                            size: 18,
                            color: kGreenDark,
                          ),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'ดูหน้าเปรียบเทียบสัดส่วนพลังงาน & สถิติ',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: kGreenDark,
                              ),
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: kGreenDark,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ประวัติการรับประทานอาหาร',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: kInk,
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/history'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(
                    Icons.history_rounded,
                    size: 16,
                    color: kGreenDark,
                  ),
                  label: const Text(
                    'ดูประวัติย้อนหลังทั้งหมด',
                    style: TextStyle(
                      fontSize: 12,
                      color: kGreenDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (meals.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kBorder, width: 1.5),
                ),
                child: const Text(
                  'ยังไม่มีบันทึกอาหารในวันนี้ กดปุ่มสแกนอาหารด้านล่างได้เลย',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kMuted, fontSize: 13),
                ),
              )
            else
              ...meals.map((meal) {
                final mCal = (meal['calories'] as num).toDouble();
                final sharePct = goalCal > 0
                    ? ((mCal / goalCal) * 100).round()
                    : 0;
                final isHeavyMeal = mCal >= 550;
                final mealType = (meal['mealType'] as String?) ?? 'มื้ออาหาร';

                return Dismissible(
                  key: ValueKey(meal['id']),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.only(right: 20),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      color: kRedBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: kRed,
                    ),
                  ),
                  onDismissed: (_) async {
                    try {
                      await c.deleteMeal(meal['id'] as String);
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('ลบมื้ออาหารไม่สำเร็จ: $error'),
                            backgroundColor: kRed,
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kBorder, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: kInk.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: isHeavyMeal ? kRedBg : kGreenBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.restaurant_rounded,
                            color: isHeavyMeal ? kRed : kGreenDark,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meal['name'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: kInk,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${mCal.toStringAsFixed(0)} kcal • $mealType (${meal['time']} น.)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: kMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isHeavyMeal ? kRedBg : kGreenBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$sharePct% ของวัน',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isHeavyMeal ? kRed : kGreenDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Shared Meal Calorie Color Bar Widget ─────────────────────────
class MealCalorieColorBar extends StatelessWidget {
  final double breakfastCal;
  final double lunchCal;
  final double dinnerCal;
  final double snackCal;
  final bool compact;

  const MealCalorieColorBar({
    super.key,
    required this.breakfastCal,
    required this.lunchCal,
    required this.dinnerCal,
    required this.snackCal,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final total = breakfastCal + lunchCal + dinnerCal + snackCal;

    int pct(double val) => total > 0 ? ((val / total) * 100).round() : 0;

    final int bPct = pct(breakfastCal);
    final int lPct = pct(lunchCal);
    final int dPct = pct(dinnerCal);
    final int sPct = total > 0 ? (100 - bPct - lPct - dPct).clamp(0, 100) : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[
          Row(
            children: [
              const Expanded(
                child: Text(
                  'แถบสีสัดส่วนพลังงานที่รับประทานไป',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: kInk,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kGreenBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'แยกตามมื้ออาหาร',
                  style: TextStyle(
                    fontSize: 11,
                    color: kGreenDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: compact ? 10 : 16,
            child: total <= 0
                ? Container(color: Colors.grey[200])
                : Row(
                    children: [
                      if (breakfastCal > 0)
                        Expanded(
                          flex: (breakfastCal * 10).round().clamp(1, 100000),
                          child: Container(color: kBlue),
                        ),
                      if (lunchCal > 0)
                        Expanded(
                          flex: (lunchCal * 10).round().clamp(1, 100000),
                          child: Container(color: kGreen),
                        ),
                      if (dinnerCal > 0)
                        Expanded(
                          flex: (dinnerCal * 10).round().clamp(1, 100000),
                          child: Container(color: kOrange),
                        ),
                      if (snackCal > 0)
                        Expanded(
                          flex: (snackCal * 10).round().clamp(1, 100000),
                          child: Container(color: kPurple),
                        ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _ColorLegendDot(
              color: kBlue,
              label:
                  'มื้อเช้า ${breakfastCal.toStringAsFixed(0)} kcal ($bPct%)',
            ),
            _ColorLegendDot(
              color: kGreen,
              label: 'มื้อกลางวัน ${lunchCal.toStringAsFixed(0)} kcal ($lPct%)',
            ),
            _ColorLegendDot(
              color: kOrange,
              label: 'มื้อเย็น ${dinnerCal.toStringAsFixed(0)} kcal ($dPct%)',
            ),
            if (snackCal > 0)
              _ColorLegendDot(
                color: kPurple,
                label: 'มื้อว่าง ${snackCal.toStringAsFixed(0)} kcal ($sPct%)',
              ),
          ],
        ),
      ],
    );
  }
}

class _ColorLegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _ColorLegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: kInk,
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── 5.5 Calorie Comparison & Statistics Screen ─────────────────────────
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.content;
    final remaining = c.dailyGoal - c.totalDailyCalories;
    final trend = c.intakeTrendInsight;
    final goal = c.goalAndChoiceInsight;

    return BaseNavLayout(
      currentIndex: 1,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const Text(
            'คำแนะนำและการวิเคราะห์',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: kInk,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'ติดตามแนวโน้มการกินและเลือกมื้อถัดไปให้เหมาะกับเป้าหมาย',
            style: TextStyle(fontSize: 12, color: kMuted),
          ),
          const SizedBox(height: 20),
          NextMealRecommendationCard(
            nextMealLabel: c.suggestedNextMealType,
            remainingQuota: remaining,
            recommendedMeals: c.getRecommendedNextMeals(
              customRemainingQuota: remaining,
            ),
            allowQuickLog: true,
            onQuickLog: (meal) async {
              final mealName = meal['name'] as String;
              final calories = (meal['energy'] as num).toDouble();
              try {
                await c.logMeal(
                  name: mealName,
                  calories: calories,
                  mealType: c.suggestedNextMealType,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'บันทึก "$mealName" (${calories.toStringAsFixed(0)} kcal) เรียบร้อยแล้ว',
                      ),
                      backgroundColor: kGreen,
                    ),
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('บันทึกมื้ออาหารไม่สำเร็จ: $error'),
                      backgroundColor: kRed,
                    ),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: kBorder, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: kInk.withValues(alpha: 0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'วิเคราะห์การกินและเป้าหมายของคุณ',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 12),
                _InsightTile(
                  icon: (trend['isMore'] as bool)
                      ? Icons.north_east_rounded
                      : Icons.south_east_rounded,
                  iconBg: (trend['isMore'] as bool) ? kRedBg : kGreenBg,
                  iconColor: (trend['isMore'] as bool) ? kRed : kGreenDark,
                  title: trend['title'] as String,
                  description: trend['detail'] as String,
                  extraHighlight: trend['mealHighlight'] as String,
                ),
                const Divider(color: kBorder, height: 22),
                _InsightTile(
                  icon: goal['status'] == 'danger'
                      ? Icons.warning_amber_rounded
                      : (goal['status'] == 'warning'
                            ? Icons.info_outline_rounded
                            : Icons.verified_rounded),
                  iconBg: goal['status'] == 'danger' ? kRedBg : kGreenBg,
                  iconColor: goal['status'] == 'danger'
                      ? kRed
                      : (goal['status'] == 'warning' ? kOrange : kGreenDark),
                  title: 'ความเหมาะสมต่อเป้าหมาย (${c.goalType})',
                  description: goal['suitability'] as String,
                ),
                const Divider(color: kBorder, height: 22),
                _InsightTile(
                  icon: Icons.restaurant_menu_rounded,
                  iconBg: kGreenBg,
                  iconColor: kGreenDark,
                  title: 'คำแนะนำการเลือกทานมื้อถัดไป',
                  description: goal['choiceAdvice'] as String,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushReplacementNamed(context, '/stats'),
            icon: const Icon(Icons.bar_chart_rounded),
            label: const Text('ดูสถิติพลังงาน'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kGreenDark,
              side: const BorderSide(color: kBorder),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardBaselineCard extends StatelessWidget {
  final AppContent content;

  const _DashboardBaselineCard({required this.content});

  String _bmiCategory(double? bmi) {
    if (bmi == null) return 'ยังไม่มีข้อมูล';
    if (bmi < 18.5) return 'น้ำหนักน้อย';
    if (bmi < 23) return 'สมส่วน';
    if (bmi < 25) return 'น้ำหนักเกิน';
    return 'อ้วน';
  }

  @override
  Widget build(BuildContext context) {
    final bmi = content.currentBmi;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: kBorder, height: 1),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(
              child: Text(
                'ค่าพื้นฐานเมื่อเริ่มตั้งเป้าหมาย',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: kInk,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_up_rounded, color: kMuted),
          ],
        ),
        const SizedBox(height: 10),
        _DashboardBaselineMetric(
          title: 'ดัชนีมวลกาย (BMI)',
          value: bmi == null ? '--' : 'BMI ${bmi.toStringAsFixed(1)}',
          detail: _bmiCategory(bmi),
          icon: Icons.monitor_weight_outlined,
        ),
        _DashboardBaselineMetric(
          title: 'พลังงานพื้นฐาน (BMR)',
          value: '${content.basalMetabolicRate.toStringAsFixed(0)} kcal',
          icon: Icons.local_fire_department_outlined,
        ),
        _DashboardBaselineMetric(
          title: 'พลังงานที่ใช้ต่อวัน (TDEE)',
          value: '${content.maintenanceTdee.toStringAsFixed(0)} kcal',
          icon: Icons.bolt_rounded,
        ),
      ],
    );
  }
}

class _DashboardBaselineMetric extends StatelessWidget {
  final String title;
  final String value;
  final String? detail;
  final IconData icon;

  const _DashboardBaselineMetric({
    required this.title,
    required this.value,
    required this.icon,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      value,
                      style: const TextStyle(fontSize: 12, color: kMuted),
                    ),
                    if (detail != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: kGreenBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            detail!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: kGreenDark,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: kMuted, size: 20),
        ],
      ),
    );
  }
}

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  String _shortDayThai(DateTime d) {
    const days = ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.', 'อา.'];
    return days[d.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.content;
    final totalCal = c.totalDailyCalories;
    final goalCal = c.dailyGoal;
    final isOver = totalCal > goalCal;
    final remainingCal = (goalCal - totalCal).clamp(0.0, goalCal);
    final overCal = isOver ? (totalCal - goalCal) : 0.0;

    final breakfastCal = c.caloriesByMealType('มื้อเช้า');
    final lunchCal = c.caloriesByMealType('มื้อกลางวัน');
    final dinnerCal = c.caloriesByMealType('มื้อเย็น');
    final snackCal = c.caloriesByMealType('มื้อว่าง');

    final breakfastTarget = (goalCal * 0.25).roundToDouble();
    final lunchTarget = (goalCal * 0.40).roundToDouble();
    final dinnerTarget = (goalCal * 0.35).roundToDouble();

    final avg7Days = c.averageLast7DaysCalories;

    final baseDate = c.selectedDate;
    final last7Days = List.generate(7, (idx) {
      final date = baseDate.subtract(Duration(days: 6 - idx));
      return {
        'date': date,
        'calories': c.caloriesForDate(date),
        'isSelected': c.dateKey(date) == c.dateKey(baseDate),
      };
    });

    double maxChartCal = goalCal * 1.25;
    for (final item in last7Days) {
      final cal = item['calories'] as double;
      if (cal * 1.15 > maxChartCal) maxChartCal = cal * 1.15;
    }
    if (maxChartCal <= 0) maxChartCal = 2000;

    return BaseNavLayout(
      currentIndex: -1,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'เปรียบเทียบและสถิติพลังงาน',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: kInk,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'กราฟและแถบสีแสดงสัดส่วนพลังงานที่รับประทานไป',
                      style: TextStyle(fontSize: 12, color: kMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: c.selectedDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null && context.mounted) {
                    c.setSelectedDate(picked);
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: kGreenBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 13,
                        color: kGreenDark,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${c.selectedDate.day}/${c.selectedDate.month}/${c.selectedDate.year}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: kGreenDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: kBorder, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: kInk.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MealCalorieColorBar(
                  breakfastCal: breakfastCal,
                  lunchCal: lunchCal,
                  dinnerCal: dinnerCal,
                  snackCal: snackCal,
                  compact: false,
                ),
                const Divider(color: kBorder, height: 26),
                const Text(
                  'เปรียบเทียบปริมาณพลังงานกับเป้าหมายรายวัน (Progress Bar)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 14),
                _CalorieProgressBarRow(
                  label: 'พลังงานที่ทานไปแล้ววันนี้',
                  current: totalCal,
                  target: goalCal,
                  barColor: isOver ? kRed : kGreen,
                ),
                const SizedBox(height: 14),
                _CalorieProgressBarRow(
                  label: isOver
                      ? 'พลังงานที่เกินเป้าหมายวันนี้'
                      : 'โควตาพลังงานคงเหลือวันนี้',
                  current: isOver ? overCal : remainingCal,
                  target: goalCal,
                  barColor: isOver ? kRed : kBlue,
                ),
                const SizedBox(height: 14),
                _CalorieProgressBarRow(
                  label: 'มื้อเช้า (เกณฑ์แนะนำ 25% ของวัน)',
                  current: breakfastCal,
                  target: breakfastTarget,
                  barColor: kBlue,
                ),
                const SizedBox(height: 14),
                _CalorieProgressBarRow(
                  label: 'มื้อกลางวัน (เกณฑ์แนะนำ 40% ของวัน)',
                  current: lunchCal,
                  target: lunchTarget,
                  barColor: kGreenDark,
                ),
                const SizedBox(height: 14),
                _CalorieProgressBarRow(
                  label: 'มื้อเย็น (เกณฑ์แนะนำ 35% ของวัน)',
                  current: dinnerCal,
                  target: dinnerTarget,
                  barColor: kOrange,
                ),
                const SizedBox(height: 14),
                _CalorieProgressBarRow(
                  label: 'ค่าเฉลี่ยพลังงานต่อวัน (7 วันล่าสุด)',
                  current: avg7Days,
                  target: goalCal,
                  barColor: avg7Days > goalCal ? kRed : kPurple,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: kBorder, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: kInk.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'กราฟสถิติพลังงานย้อนหลัง 7 วัน',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: kInk,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: kGreenBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'เป้า ${goalCal.toStringAsFixed(0)} kcal',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: kGreenDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'แตะที่แท่งกราฟเพื่อดูสัดส่วนพลังงานของวันนั้น',
                  style: TextStyle(fontSize: 11, color: kMuted),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 170,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: last7Days.map((item) {
                      final d = item['date'] as DateTime;
                      final cal = item['calories'] as double;
                      final isSelected = item['isSelected'] as bool;
                      final isDayOver = cal > goalCal;
                      final barHeight = cal <= 0
                          ? 8.0
                          : ((cal / maxChartCal) * 120).clamp(14.0, 120.0);

                      final Color barColor = cal <= 0
                          ? Colors.grey.shade200
                          : (isDayOver
                                ? kRed
                                : (isSelected ? kGreenDark : kGreen));

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => c.setSelectedDate(d),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                cal > 0 ? cal.toStringAsFixed(0) : '-',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isDayOver
                                      ? kRed
                                      : (isSelected ? kGreenDark : kMuted),
                                ),
                              ),
                              const SizedBox(height: 6),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                width: 24,
                                height: barHeight,
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: isSelected
                                      ? Border.all(color: kInk, width: 1.5)
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _shortDayThai(d),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isSelected ? kInk : kMuted,
                                ),
                              ),
                              Text(
                                '${d.day}/${d.month}',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isSelected ? kGreenDark : kMuted,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),
                const Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _ColorLegendDot(
                      color: kGreen,
                      label: 'อยู่ในเกณฑ์เป้าหมาย',
                    ),
                    _ColorLegendDot(color: kRed, label: 'เกินเป้าหมายรายวัน'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          PrimaryButton(
            'ดูประวัติรายการอาหารแยกตามวันและเวลา',
            () => Navigator.pushReplacementNamed(context, '/history'),
            color: kGreenBg,
            textColor: kGreenDark,
            icon: Icons.history_rounded,
          ),
        ],
      ),
    );
  }
}

class _CalorieProgressBarRow extends StatelessWidget {
  final String label;
  final double current;
  final double target;
  final Color barColor;

  const _CalorieProgressBarRow({
    required this.label,
    required this.current,
    required this.target,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final pct = target > 0 ? ((current / target) * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kInk,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${current.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} kcal ($pct%)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 10,
            backgroundColor: barColor.withValues(alpha: 0.14),
            color: barColor,
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── 5.6 Meal History Screen ─────────────────────────
class MealHistoryScreen extends StatefulWidget {
  const MealHistoryScreen({super.key});

  @override
  State<MealHistoryScreen> createState() => _MealHistoryScreenState();
}

class _MealHistoryScreenState extends State<MealHistoryScreen> {
  String _searchQuery = '';
  String _selectedRange = 'ทั้งหมด';

  static const _thaiMonths = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];

  String _formatSectionDate(DateTime date, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;
    final fullDate =
        '${date.day} ${_thaiMonths[date.month - 1]} ${date.year + 543}';
    if (diff == 0) return 'วันนี้ • $fullDate';
    if (diff == 1) return 'เมื่อวาน • $fullDate';
    return fullDate;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.content;
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);

    final sortedKeys = c.mealsByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final List<MapEntry<String, List<DynamicMap>>> groupedSections = [];

    for (final key in sortedKeys) {
      final date = c.parseDateKey(key);
      final dateOnly = DateTime(date.year, date.month, date.day);
      final dayDiff = todayOnly.difference(dateOnly).inDays;

      if (_selectedRange == 'วันนี้' && dayDiff != 0) continue;
      if (_selectedRange == '7 วันล่าสุด' && (dayDiff < 0 || dayDiff > 6)) {
        continue;
      }

      final rawList = List<DynamicMap>.from(c.mealsByDate[key] ?? []);
      rawList.sort(
        (a, b) =>
            (a['time'] as String? ?? '').compareTo(b['time'] as String? ?? ''),
      );

      final filteredList = _searchQuery.trim().isEmpty
          ? rawList
          : rawList
                .where(
                  (m) => (m['name'] as String).toLowerCase().contains(
                    _searchQuery.trim().toLowerCase(),
                  ),
                )
                .toList();

      if (filteredList.isNotEmpty) {
        groupedSections.add(MapEntry(key, filteredList));
      }
    }

    final totalEntriesCount = groupedSections.fold<int>(
      0,
      (sum, e) => sum + e.value.length,
    );

    return BaseNavLayout(
      currentIndex: 3,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ประวัติย้อนหลังของเมนูที่บันทึก',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: kInk,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'แสดงรายการอาหารที่รับประทานแยกตามวันและเวลา',
                      style: TextStyle(fontSize: 12, color: kMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: kGreenBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalEntriesCount รายการ',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: kGreenDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          CleanTextField(
            hint: 'ค้นหาชื่อเมนูอาหารในประวัติ...',
            icon: Icons.search,
            onChanged: (v) => setState(() => _searchQuery = v),
          ),

          Row(
            children: ['ทั้งหมด', 'วันนี้', '7 วันล่าสุด'].map((label) {
              final isSelected = _selectedRange == label;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  selectedColor: kGreenBg,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? kGreenDark : kMuted,
                  ),
                  side: BorderSide(
                    color: isSelected ? kGreen : kBorder,
                    width: 1.5,
                  ),
                  onSelected: (_) => setState(() => _selectedRange = label),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          if (groupedSections.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: kBorder, width: 1.5),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.history_toggle_off_rounded,
                    size: 46,
                    color: kMuted,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'ไม่พบประวัติการรับประทานอาหารในช่วงที่เลือก',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: kInk,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'ลองเปลี่ยนตัวกรองช่วงเวลา หรือสแกนอาหารเพื่อบันทึกมื้อใหม่',
                    style: TextStyle(fontSize: 12, color: kMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...groupedSections.map((section) {
              final dateKeyStr = section.key;
              final sectionDate = c.parseDateKey(dateKeyStr);
              final dayMeals = section.value;
              final dayTotalCal = dayMeals.fold<double>(
                0.0,
                (sum, m) => sum + ((m['calories'] as num?)?.toDouble() ?? 0.0),
              );

              return Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: kBorder, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: kInk.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: kGreenBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.calendar_month_rounded,
                                size: 16,
                                color: kGreenDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatSectionDate(sectionDate, now),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: kInk,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: dayTotalCal > c.dailyGoal
                                ? kRedBg
                                : kGreenBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'รวม ${dayTotalCal.toStringAsFixed(0)} kcal',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: dayTotalCal > c.dailyGoal
                                  ? kRed
                                  : kGreenDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: kBorder, height: 22),

                    ...List.generate(dayMeals.length, (idx) {
                      final meal = dayMeals[idx];
                      final isLast = idx == dayMeals.length - 1;
                      final cal = (meal['calories'] as num).toDouble();
                      final weightGrams =
                          (meal['weightGrams'] as num?)?.toInt() ?? 300;
                      final sharePct = c.dailyGoal > 0
                          ? ((cal / c.dailyGoal) * 100).round()
                          : 0;
                      final mealType =
                          (meal['mealType'] as String?) ?? 'มื้ออาหาร';
                      final time = (meal['time'] as String?) ?? '--:--';

                      return Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 66,
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: kBorder),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '$time น.',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: kInk,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    mealType,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: kGreenDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    meal['name'] as String,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: kInk,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'พลังงาน ${cal.toStringAsFixed(0)} kcal ($sharePct% ของวัน) • ปริมาณ ~$weightGrams กรัม',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: kMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'ลบรายการนี้',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: kMuted,
                              ),
                              onPressed: () async {
                                try {
                                  await c.deleteMeal(
                                    meal['id'] as String,
                                    fromDateKey: dateKeyStr,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'ลบรายการอาหารออกจากประวัติแล้ว',
                                        ),
                                        backgroundColor: kGreen,
                                      ),
                                    );
                                  }
                                } catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'ลบมื้ออาหารไม่สำเร็จ: $error',
                                        ),
                                        backgroundColor: kRed,
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _MetricMiniRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _MetricMiniRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: kMuted)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _InsightTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String description;
  final String extraHighlight;

  const _InsightTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.description,
    this.extraHighlight = '',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: kInk,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: kMuted,
                  height: 1.4,
                ),
              ),
              if (extraHighlight.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: kGreenBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    extraHighlight,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kGreenDark,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Photo Error Alert / Exception Flow Widget ─────────────────────────
class PhotoExceptionInfo {
  final String code;
  final String title;
  final String description;
  final List<String> tips;

  const PhotoExceptionInfo({
    required this.code,
    required this.title,
    required this.description,
    required this.tips,
  });

  static const noFoodDetected = PhotoExceptionInfo(
    code: 'ERR_NO_FOOD_DETECTED',
    title: 'ไม่พบอาหารในภาพถ่าย',
    description: 'ระบบ AI ไม่สามารถตรวจจับจานอาหารในภาพนี้ได้ อาจเกิดจากมุมกล้องไกลเกินไปหรือมีวัตถุอื่นบดบังอาหาร',
    tips: [
      'จัดจานอาหารให้อยู่กึ่งกลางกรอบสี่เหลี่ยมสีเขียว',
      'ถ่ายภาพในมุมเฉียง 45 องศา หรือมุมบนให้เห็นอาหารชัดเจน',
      'หลีกเลี่ยงการถ่ายติดสิ่งของที่ไม่ใช่อาหารเป็นส่วนใหญ่',
    ],
  );

  static const blurryOrDark = PhotoExceptionInfo(
    code: 'ERR_LOW_IMAGE_QUALITY',
    title: 'ภาพไม่คมชัดหรือแสงสว่างน้อยเกินไป',
    description: 'ภาพถ่ายมีความเบลอจากการเคลื่อนไหวหรือมืดเกินไป ทำให้ไม่สามารถประเมินชนิดและปริมาณอาหารได้แม่นยำ',
    tips: [
      'กดเปิดปุ่ม "แฟลช" มุมขวาล่างหากอยู่ในที่แสงน้อย',
      'ถือโทรศัพท์ให้นิ่งประมาณ 1 วินาทีขณะกดปุ่มถ่ายภาพ',
      'เช็ดเลนส์กล้องให้สะอาดก่อนทำการสแกนอาหาร',
    ],
  );

  static const invalidOrCorrupted = PhotoExceptionInfo(
    code: 'ERR_INVALID_IMAGE_FILE',
    title: 'ไฟล์รูปภาพไม่รองรับหรือเกิดข้อผิดพลาด',
    description: 'ไม่สามารถอ่านข้อมูลไฟล์ภาพได้ หรือไฟล์มีขนาดใหญ่เกิน 10 MB กรุณาเลือกรูปภาพใหม่ (รองรับ JPG, PNG)',
    tips: [
      'ตรวจสอบว่าไฟล์ภาพไม่เสียหายและบันทึกอยู่ในเครื่องเรียบร้อย',
      'เลือกภาพที่มีขนาดไม่เกิน 10 MB',
      'ลองถ่ายภาพใหม่อีกครั้งด้วยกล้องในแอปพลิเคชัน',
    ],
  );
}

Future<void> showPhotoExceptionSheet(
  BuildContext context, {
  required PhotoExceptionInfo error,
  required VoidCallback onRetryCamera,
  required VoidCallback onPickGallery,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kRedBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: kRed,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: kRedBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Exception Flow • ${error.code}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: kRed,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        error.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: kInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              error.description,
              style: const TextStyle(fontSize: 13, color: kMuted, height: 1.45),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kGreenBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kGreen.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 16,
                        color: kGreenDark,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'คำแนะนำในการแก้ไข',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: kGreenDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...error.tips.map(
                    (tip) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(
                              color: kGreenDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              tip,
                              style: const TextStyle(
                                fontSize: 12,
                                color: kInk,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton('ถ่ายภาพใหม่อีกครั้ง', () {
              Navigator.pop(ctx);
              onRetryCamera();
            }, icon: Icons.camera_alt_rounded),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kInk,
                  side: const BorderSide(color: kBorder, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  onPickGallery();
                },
                icon: const Icon(Icons.photo_library_outlined, size: 19),
                label: const Text(
                  'เลือกภาพใหม่จากคลังภาพ',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ───────────────────────── 6. Capture ─────────────────────────
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});
  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  CameraController? _controller;
  Future<void>? _initFuture;
  bool _flashOn = false;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    if (cameras.isNotEmpty) {
      _controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _initFuture = _controller!.initialize();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _triggerException(PhotoExceptionInfo info) {
    if (!mounted) return;
    showPhotoExceptionSheet(
      context,
      error: info,
      onRetryCamera: () {},
      onPickGallery: _pickFromGallery,
    );
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่พบฮาร์ดแวร์กล้องบนอุปกรณ์นี้'),
          backgroundColor: kRed,
        ),
      );
      return;
    }
    final next = !_flashOn;
    try {
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (!mounted) return;
      setState(() => _flashOn = next);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('อุปกรณ์นี้ไม่รองรับโหมดแฟลช'),
          backgroundColor: kRed,
        ),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      final imageBytes = await picked.readAsBytes();
      if (!mounted) return;

      if (imageBytes.isEmpty ||
          imageBytes.length < 100 ||
          imageBytes.length > 10 * 1024 * 1024) {
        _triggerException(PhotoExceptionInfo.invalidOrCorrupted);
        return;
      }

      Navigator.pushNamed(
        context,
        '/analysis',
        arguments: {'bytes': imageBytes},
      );
    } catch (_) {
      _triggerException(PhotoExceptionInfo.invalidOrCorrupted);
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      Navigator.pushNamed(context, '/analysis');
      return;
    }
    setState(() => _isCapturing = true);
    try {
      final file = await controller.takePicture();
      final imageBytes = await file.readAsBytes();
      if (!mounted) return;

      if (imageBytes.isEmpty || imageBytes.length < 100) {
        _triggerException(PhotoExceptionInfo.blurryOrDark);
        return;
      }
      Navigator.pushNamed(
        context,
        '/analysis',
        arguments: {'bytes': imageBytes},
      );
    } catch (_) {
      _triggerException(PhotoExceptionInfo.blurryOrDark);
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _showSimulateErrorMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ทดสอบแจ้งเตือนข้อผิดพลาดภาพถ่าย (Exception Flow)',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: kInk,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'เลือกรูปแบบข้อผิดพลาดเพื่อตรวจสอบการทำงานของระบบแจ้งเตือน',
                style: TextStyle(fontSize: 12, color: kMuted),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: kRedBg,
                  child: Icon(Icons.no_food_outlined, color: kRed, size: 20),
                ),
                title: const Text(
                  '1. ไม่พบอาหารในภาพถ่าย',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: const Text(
                  'จำลองกรณีถ่ายติดวัตถุอื่นที่ไม่ใช่อาหาร',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(
                    context,
                    '/analysis',
                    arguments: {
                      'simulateError': PhotoExceptionInfo.noFoodDetected,
                    },
                  );
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: kRedBg,
                  child: Icon(Icons.blur_on_rounded, color: kRed, size: 20),
                ),
                title: const Text(
                  '2. ภาพเบลอหรือแสงสว่างไม่พอ',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: const Text(
                  'จำลองกรณีมือสั่นหรือถ่ายในที่มืดเกินไป',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _triggerException(PhotoExceptionInfo.blurryOrDark);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: kRedBg,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: kRed,
                    size: 20,
                  ),
                ),
                title: const Text(
                  '3. ไฟล์ภาพเสียหาย / ขนาดเกินกำหนด',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: const Text(
                  'จำลองกรณีเลือกไฟล์จากคลังภาพไม่ได้',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _triggerException(PhotoExceptionInfo.invalidOrCorrupted);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseNavLayout(
      currentIndex: 2,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'สแกนอาหารด้วย AI',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: kInk,
                  ),
                ),
                InkWell(
                  onTap: _showSimulateErrorMenu,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: kRedBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kRed.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: kRed,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'ทดสอบแจ้งเตือนภาพ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: kRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        border: Border.all(color: kBorder, width: 1.5),
                      ),
                      child: _controller == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.restaurant_rounded,
                                  size: 64,
                                  color: kGreen,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'โหมดจำลองกล้อง (กดปุ่มถ่ายภาพเพื่อทดสอบวิเคราะห์)',
                                  style: TextStyle(
                                    color: kMuted,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : FutureBuilder<void>(
                              future: _initFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.done) {
                                  if (snapshot.hasError) {
                                    return const Center(
                                      child: Text(
                                        'ไม่สามารถเริ่มต้นกล้องได้ กรุณาเลือกภาพจากคลังภาพ',
                                        style: TextStyle(color: kMuted),
                                      ),
                                    );
                                  }
                                  return CameraPreview(_controller!);
                                }
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: kGreen,
                                  ),
                                );
                              },
                            ),
                    ),
                    Center(
                      child: Container(
                        width: 230,
                        height: 230,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: kGreen.withValues(alpha: 0.85),
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      left: 24,
                      right: 24,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: kInk.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'จัดจานอาหารให้อยู่กึ่งกลางกรอบเพื่อประเมินแคลอรี่',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    InkWell(
                      onTap: _pickFromGallery,
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: kBorder, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.photo_library_outlined,
                          color: kInk,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'คลังภาพ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kMuted,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: _isCapturing ? null : _capturePhoto,
                  borderRadius: BorderRadius.circular(42),
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: kGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: kGreen.withValues(alpha: 0.38),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: _isCapturing
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                  ),
                ),
                Column(
                  children: [
                    InkWell(
                      onTap: _toggleFlash,
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: _flashOn ? kGreenBg : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _flashOn ? kGreen : kBorder,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          _flashOn
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          color: _flashOn ? kGreenDark : kInk,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'แฟลช',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── 7. Analysis + Next-Meal Recommendation + Confirmation ─────────────────────────
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  int _selectedMenuIndex = 0;
  TimeOfDay _selectedTime = TimeOfDay.now();

  bool _isAnalyzing = true;
  Uint8List? _imageBytes;
  PhotoExceptionInfo? _analysisException;
  bool _argsRead = false;

  @override
  void initState() {
    super.initState();
    _startAnalysis();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsRead) {
      final rawArgs = ModalRoute.of(context)?.settings.arguments;
      if (rawArgs is Uint8List) {
        _imageBytes = rawArgs;
      } else if (rawArgs is Map) {
        _imageBytes = rawArgs['bytes'] as Uint8List?;
        _analysisException = rawArgs['simulateError'] as PhotoExceptionInfo?;
      }
      _argsRead = true;
    }
  }

  Future<void> _startAnalysis() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _isAnalyzing = false);
  }

  final List<DynamicMap> _aiPredictions = [
    {
      'name': 'ข้าวมันไก่ต้ม',
      'confidence': 95.2,
      'calories': 590.0,
      'depthCm': 3.5,
      'weightGrams': 310,
      'advice': 'ข้าวมันไก่ 1 จานให้พลังงานค่อนข้างสูง (590 kcal) หากกำลังลดน้ำหนักแนะนำเลือกทานไม่ติดหนังหรือลดปริมาณข้าวลงครึ่งหนึ่ง (0.5x)',
    },
    {
      'name': 'ข้าวกระเพราหมูสับไข่ดาว',
      'confidence': 3.4,
      'calories': 540.0,
      'depthCm': 3.4,
      'weightGrams': 285,
      'advice': 'มื้อนี้มีพลังงานปานกลางค่อนข้างสูง แนะนำเสริมผักสดหรือผลไม้ไม่หวานในมื้อถัดไปเพื่อความสมดุล',
    },
    {
      'name': 'สุกี้น้ำรวมมิตร',
      'confidence': 1.4,
      'calories': 320.0,
      'depthCm': 4.0,
      'weightGrams': 350,
      'advice': 'เมนูนี้พลังงานกำลังดี มีผักเยอะและอิ่มท้อง เหมาะมากสำหรับผู้ที่ต้องการควบคุมหรือลดน้ำหนัก',
    },
  ];

  String _guessMealType(TimeOfDay t) {
    if (t.hour >= 5 && t.hour < 11) return 'มื้อเช้า';
    if (t.hour >= 11 && t.hour < 15) return 'มื้อกลางวัน';
    if (t.hour >= 17 && t.hour < 21) return 'มื้อเย็น';
    return 'มื้อว่าง';
  }

  String _nextMealAfter(String currentMealType) {
    if (currentMealType == 'มื้อเช้า') return 'มื้อกลางวัน';
    if (currentMealType == 'มื้อกลางวัน') return 'มื้อเย็น';
    return 'มื้อว่าง';
  }

  void _showCustomFoodDialog() {
    final currentFood = _aiPredictions[_selectedMenuIndex];
    final nameCtrl = TextEditingController(text: currentFood['name'] as String);
    final calCtrl = TextEditingController(
      text: (currentFood['calories'] as double).toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          String? nameError;
          String? calError;

          void trySave() {
            final customName = nameCtrl.text.trim();
            final parsedCal = double.tryParse(calCtrl.text.trim());
            setDialogState(() {
              nameError = customName.isEmpty ? 'กรุณากรอกชื่อเมนูอาหาร' : null;
              calError = calCtrl.text.trim().isEmpty
                  ? 'กรุณากรอกพลังงาน'
                  : (parsedCal == null
                        ? 'พลังงานต้องเป็นตัวเลขเท่านั้น'
                        : (parsedCal <= 0 ? 'พลังงานต้องมากกว่า 0' : null));
            });
            if (nameError != null || calError != null) return;

            setState(() {
              _aiPredictions[_selectedMenuIndex] = {
                ..._aiPredictions[_selectedMenuIndex],
                'name': customName,
                'calories': parsedCal!,
                'confidence': 100.0,
              };
            });
            Navigator.pop(ctx);
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'แก้ไขชื่อ / พลังงานอาหาร',
              style: TextStyle(fontWeight: FontWeight.bold, color: kInk),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'ชื่อเมนูอาหาร',
                    border: const OutlineInputBorder(),
                    errorText: nameError,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: calCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'พลังงาน (กิโลแคลอรี)',
                    border: const OutlineInputBorder(),
                    errorText: calError,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ยกเลิก', style: TextStyle(color: kMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kGreen),
                onPressed: trySave,
                child: const Text(
                  'บันทึกการแก้ไข',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showConfirmAndSaveSheet({
    required String foodName,
    required double calories,
    required int weightGrams,
    required int mealSharePct,
  }) {
    String selectedMealType = _guessMealType(_selectedTime);
    final formattedTime =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')} น.';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Row(
                  children: [
                    Icon(Icons.fact_check_rounded, color: kGreenDark, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'ยืนยันการบันทึกข้อมูลอาหาร',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: kInk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'ตรวจสอบรายละเอียดเมนูและเลือกมื้ออาหารก่อนบันทึกลงในไดอารี่',
                  style: TextStyle(fontSize: 12, color: kMuted),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kGreenBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: kGreen.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ชื่อเมนูอาหาร',
                            style: TextStyle(fontSize: 12, color: kMuted),
                          ),
                          Flexible(
                            child: Text(
                              foodName,
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: kInk,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'พลังงานทั้งหมด',
                            style: TextStyle(fontSize: 12, color: kMuted),
                          ),
                          Text(
                            '${calories.toStringAsFixed(0)} kcal ($mealSharePct% ของวัน)',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: kGreenDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ปริมาณโดยประมาณ',
                            style: TextStyle(fontSize: 12, color: kMuted),
                          ),
                          Text(
                            '~$weightGrams กรัม',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: kInk,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'เวลาที่รับประทาน',
                            style: TextStyle(fontSize: 12, color: kMuted),
                          ),
                          Text(
                            formattedTime,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: kInk,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'เลือกมื้ออาหาร',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['มื้อเช้า', 'มื้อกลางวัน', 'มื้อเย็น', 'มื้อว่าง']
                      .map((mType) {
                        final selected = selectedMealType == mType;
                        return ChoiceChip(
                          label: Text(mType),
                          selected: selected,
                          selectedColor: kGreen,
                          backgroundColor: Colors.grey[100],
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : kInk,
                          ),
                          side: BorderSide.none,
                          onSelected: (_) =>
                              setSheetState(() => selectedMealType = mType),
                        );
                      })
                      .toList(),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kMuted,
                            side: const BorderSide(color: kBorder, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => Navigator.pop(sheetCtx),
                          child: const Text(
                            'ยกเลิก',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: PrimaryButton('ยืนยันการบันทึก', () async {
                        Navigator.pop(sheetCtx);
                        try {
                          await context.content.logMeal(
                            name: foodName,
                            calories: calories,
                            weightGrams: weightGrams,
                            mealType: selectedMealType,
                            customTime: _selectedTime,
                          );
                          if (mounted) {
                            _showSaveSuccessDialog(
                              foodName: foodName,
                              calories: calories,
                              mealType: selectedMealType,
                              timeLabel: formattedTime,
                            );
                          }
                        } catch (error) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'บันทึกมื้ออาหารไม่สำเร็จ: $error',
                                ),
                                backgroundColor: kRed,
                              ),
                            );
                          }
                        }
                      }, icon: Icons.check_circle_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSaveSuccessDialog({
    required String foodName,
    required double calories,
    required String mealType,
    required String timeLabel,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: kGreenBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: kGreen,
                size: 46,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'บันทึกข้อมูลสำเร็จ!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: kInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'บันทึกเมนู "$foodName" (${calories.toStringAsFixed(0)} kcal)\nใน$mealType เวลา $timeLabel เรียบร้อยแล้ว',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: kMuted, height: 1.45),
            ),
            const SizedBox(height: 22),
            PrimaryButton('กลับไปหน้าหลัก', () {
              Navigator.pop(dialogCtx);
              Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
            }, icon: Icons.home_rounded),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/history',
                  (_) => false,
                );
              },
              child: const Text(
                'ดูประวัติการบันทึกย้อนหลัง',
                style: TextStyle(
                  color: kGreenDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isAnalyzing) {
      return Scaffold(
        appBar: const CleanAppBar(title: 'ผลการวิเคราะห์อาหาร'),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: kGreenBg,
                  shape: BoxShape.circle,
                ),
                child: const CircularProgressIndicator(color: kGreen),
              ),
              const SizedBox(height: 20),
              const Text(
                'กำลังวิเคราะห์ภาพอาหารด้วย AI...',
                style: TextStyle(
                  color: kInk,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'กำลังประเมินชนิดเมนู ปริมาณ และคัดเมนูแนะนำสำหรับมื้อถัดไป',
                style: TextStyle(color: kMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (_analysisException != null) {
      final err = _analysisException!;
      return Scaffold(
        appBar: const CleanAppBar(title: 'แจ้งเตือนข้อผิดพลาดภาพถ่าย'),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: kRedBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: kRed.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.error_outline_rounded,
                              color: kRed,
                              size: 42,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              err.code,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: kRed,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            err.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: kInk,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            err.description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: kMuted,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kBorder, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.tips_and_updates_outlined,
                                color: kGreenDark,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'แนวทางการแก้ไขปัญหา',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: kInk,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...err.tips.map(
                            (t) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    size: 16,
                                    color: kGreen,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      t,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: kInk,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                'กลับไปถ่ายภาพใหม่อีกครั้ง',
                () => Navigator.pop(context),
                icon: Icons.camera_alt_rounded,
              ),
            ],
          ),
        ),
      );
    }

    final c = context.content;
    final currentDailyCalories = c.totalDailyCalories;
    final dailyCalorieGoal = c.dailyGoal;

    final currentFood = _aiPredictions[_selectedMenuIndex];
    final currentFoodName = currentFood['name'] as String;
    final double finalCalories = currentFood['calories'] as double;
    final int mealSharePct = dailyCalorieGoal > 0
        ? ((finalCalories / dailyCalorieGoal) * 100).round()
        : 0;

    final int weight = currentFood['weightGrams'] as int;
    final double depthCm = currentFood['depthCm'] as double;

    final double projectedTotal = currentDailyCalories + finalCalories;
    final double diffFromGoal = dailyCalorieGoal - projectedTotal;
    final bool isOverLimit = projectedTotal > dailyCalorieGoal;
    final bool isGoalReached =
        !isOverLimit && dailyCalorieGoal > 0 && diffFromGoal.abs() < 1;
    final double progressRatio = dailyCalorieGoal > 0
        ? (projectedTotal / dailyCalorieGoal).clamp(0.0, 1.0)
        : 0.0;

    final String formattedTime =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')} น.';

    final bool isTooMuchForGoal =
        (c.goalType.contains('ลดน้ำหนัก') && finalCalories >= 550) ||
        isOverLimit;

    final currentGuessedMeal = _guessMealType(_selectedTime);
    final upcomingMealType = _nextMealAfter(currentGuessedMeal);
    final nextMealSuggestions = c.getRecommendedNextMeals(
      customRemainingQuota: diffFromGoal,
      excludeMenuName: currentFoodName,
      limit: 3,
    );

    return Scaffold(
      appBar: const CleanAppBar(title: 'ผลการวิเคราะห์อาหาร'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  height: 190,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border.all(color: kBorder, width: 1.5),
                  ),
                  child: _imageBytes != null
                      ? Image.memory(
                          _imageBytes!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 190,
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.restaurant_menu_rounded,
                              size: 52,
                              color: kGreen,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'ภาพถ่ายอาหารที่สแกน',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, size: 14, color: kGreen),
                      const SizedBox(width: 6),
                      Text(
                        'ความแม่นยำ ${currentFood['confidence']}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: kGreenDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: kInk.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.layers_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'ความลึก ${depthCm.toStringAsFixed(1)} ซม. • ปริมาณ ~$weight กรัม',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  currentFoodName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: kInk,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _showCustomFoodDialog,
                icon: const Icon(Icons.edit_note, size: 18, color: kGreenDark),
                label: const Text(
                  'แก้ไขเมนู',
                  style: TextStyle(
                    color: kGreenDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_aiPredictions.length, (index) {
                final item = _aiPredictions[index];
                final isSelected = index == _selectedMenuIndex;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('${item['name']} (${item['confidence']}%)'),
                    selected: isSelected,
                    selectedColor: kGreenBg,
                    backgroundColor: Colors.grey[50],
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: isSelected ? kGreenDark : kMuted,
                    ),
                    side: BorderSide(color: isSelected ? kGreen : kBorder),
                    onSelected: (_) =>
                        setState(() => _selectedMenuIndex = index),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: kGreenBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: kGreen.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'พลังงานมื้อนี้',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: kInk,
                          ),
                        ),
                        Text(
                          'คิดเป็น $mealSharePct% ของเป้าหมายทั้งวัน',
                          style: const TextStyle(fontSize: 11, color: kMuted),
                        ),
                      ],
                    ),
                    Text(
                      '${finalCalories.toStringAsFixed(0)} kcal',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: kGreenDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'เวลาที่รับประทาน:',
                      style: TextStyle(
                        fontSize: 12,
                        color: kMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime,
                        );
                        if (picked != null) {
                          setState(() => _selectedTime = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: kGreen.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 14,
                              color: kGreenDark,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              formattedTime,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: kInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isTooMuchForGoal ? kRedBg : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isTooMuchForGoal
                    ? kRed.withValues(alpha: 0.45)
                    : kBorder,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isTooMuchForGoal
                          ? Icons.warning_amber_rounded
                          : Icons.recommend_rounded,
                      color: isTooMuchForGoal ? kRed : kGreenDark,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isTooMuchForGoal
                            ? 'ประเมินมื้อนี้: พลังงานค่อนข้างสูงสำหรับเป้าหมาย "${c.goalType}"'
                            : 'ประเมินมื้อนี้: ปริมาณเหมาะสมกับเป้าหมาย "${c.goalType}"',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: isTooMuchForGoal ? kRed : kInk,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  currentFood['advice'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    color: kMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isOverLimit
                  ? kRedBg
                  : (isGoalReached ? kGreenBg : Colors.white),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isOverLimit
                    ? kRed.withValues(alpha: 0.5)
                    : (isGoalReached ? kGreen : kBorder),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isOverLimit
                          ? Icons.warning_amber_rounded
                          : isGoalReached
                          ? Icons.check_circle
                          : Icons.track_changes,
                      color: isOverLimit
                          ? kRed
                          : (isGoalReached ? kGreenDark : kGreen),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isOverLimit
                            ? 'แจ้งเตือน: พลังงานเกินเป้าหมายรายวัน!'
                            : isGoalReached
                            ? 'ยินดีด้วย! พลังงานถึงเป้าหมายวันนี้พอดี'
                            : 'ผลลัพธ์เทียบกับเป้าหมายวันนี้',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: isOverLimit
                              ? kRed
                              : (isGoalReached ? kGreenDark : kInk),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progressRatio,
                    minHeight: 10,
                    backgroundColor: isOverLimit
                        ? Colors.red.withValues(alpha: 0.15)
                        : kGreenBg,
                    color: isOverLimit
                        ? kRed
                        : (isGoalReached ? kGreenDark : kGreen),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'รวมมื้อนี้: ${projectedTotal.toStringAsFixed(0)} / ${dailyCalorieGoal.toStringAsFixed(0)} kcal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isOverLimit
                            ? kRed
                            : (isGoalReached ? kGreenDark : kMuted),
                      ),
                    ),
                    Text(
                      isOverLimit
                          ? 'เกิน ${diffFromGoal.abs().toStringAsFixed(0)} kcal'
                          : isGoalReached
                          ? 'ถึงเป้าหมายพอดี!'
                          : 'เหลืออีก ${diffFromGoal.toStringAsFixed(0)} kcal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isOverLimit
                            ? kRed
                            : (isGoalReached ? kGreenDark : kGreenDark),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── แนะนำอาหารมื้อต่อไปทันทีหลังวิเคราะห์ ──
          NextMealRecommendationCard(
            nextMealLabel: upcomingMealType,
            remainingQuota: diffFromGoal,
            recommendedMeals: nextMealSuggestions,
            allowQuickLog: false,
          ),
          const SizedBox(height: 22),

          PrimaryButton(
            'บันทึกลงในไดอารี่',
            () => _showConfirmAndSaveSheet(
              foodName: currentFoodName,
              calories: finalCalories,
              weightGrams: weight,
              mealSharePct: mealSharePct,
            ),
            icon: Icons.check_rounded,
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── 8. Profile ─────────────────────────
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showEditAccountDialog(BuildContext context) {
    final c = context.content;
    final nameCtrl = TextEditingController(text: c.fullName);
    final emailCtrl = TextEditingController(text: c.email);
    DateTime tempBirthDate = c.birthDate ?? DateTime(2000, 1, 1);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'แก้ไขข้อมูลบัญชี',
            style: TextStyle(fontWeight: FontWeight.w800, color: kInk),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ชื่อ - นามสกุล',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: kMuted,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'กรอกชื่อ - นามสกุล',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'อีเมล',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: kMuted,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'กรอกอีเมล',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'วันเกิด (ปฏิทิน)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: kMuted,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: tempBirthDate,
                      firstDate: DateTime(1920),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => tempBirthDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${tempBirthDate.day}/${tempBirthDate.month}/${tempBirthDate.year}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: kInk,
                          ),
                        ),
                        const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: kGreen,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก', style: TextStyle(color: kMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final newName = nameCtrl.text.trim();
                final newEmail = emailCtrl.text.trim();
                if (newName.isEmpty || newEmail.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('กรุณากรอกข้อมูลให้ครบถ้วน'),
                      backgroundColor: kRed,
                    ),
                  );
                  return;
                }
                if (!RegExp(r'^[\w\.\+\-]+@[\w\-]+\.[\w\.\-]+$')
                    .hasMatch(newEmail)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'รูปแบบอีเมลไม่ถูกต้อง เช่น name@example.com',
                      ),
                      backgroundColor: kRed,
                    ),
                  );
                  return;
                }
                try {
                  final updated = await c.updateAccountInfo(
                    name: newName,
                    newEmail: newEmail,
                    newBirthDate: tempBirthDate,
                  );
                  if (!context.mounted) return;
                  if (!updated) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('อีเมลนี้มีบัญชีอยู่แล้ว'),
                        backgroundColor: kRed,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('บันทึกข้อมูลบัญชีเรียบร้อยแล้ว'),
                      backgroundColor: kGreen,
                    ),
                  );
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('บันทึกข้อมูลบัญชีไม่สำเร็จ: $error'),
                        backgroundColor: kRed,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'บันทึก',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.content;
    final bmi = c.currentBmi;

    return BaseNavLayout(
      currentIndex: 4,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Center(
            child: Text(
              'บัญชี',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: kInk,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: kBorder, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: kGreenBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: kGreen.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: kGreenDark,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.fullName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: kInk,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        c.email,
                        style: const TextStyle(fontSize: 12, color: kMuted),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _showEditAccountDialog(context),
                  child: const Text(
                    'แก้ไข',
                    style: TextStyle(
                      color: kGreenDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kBorder, width: 1.5),
            ),
            child: Column(
              children: [
                _AccountMenuRow(
                  icon: Icons.person_outline_rounded,
                  title: 'ข้อมูลส่วนตัว',
                  onTap: () => _showEditAccountDialog(context),
                ),
                const Divider(height: 1, color: kBorder),
                _AccountMenuRow(
                  icon: Icons.monitor_weight_outlined,
                  title: 'สุขภาพและเป้าหมาย',
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/health',
                    arguments: {'fromProfile': true},
                  ),
                ),
                const Divider(height: 1, color: kBorder),
                _AccountMenuRow(
                  icon: Icons.lock_outline_rounded,
                  title: 'เปลี่ยนรหัสผ่าน',
                  onTap: () => Navigator.pushNamed(context, '/change_password'),
                ),
                const Divider(height: 1, color: kBorder),
                _AccountMenuRow(
                  icon: Icons.settings_outlined,
                  title: 'ตั้งค่าแอป',
                  onTap: () => Navigator.pushNamed(context, '/account'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _MealStreakCard(content: c),
          const SizedBox(height: 18),
          _InfoCard(
            title: 'ข้อมูลสุขภาพและเป้าหมาย',
            items: {
              'เพศ': c.gender,
              'น้ำหนัก': c.weightKg > 0
                  ? '${c.weightKg.toStringAsFixed(1)} กิโลกรัม'
                  : '--',
              'ส่วนสูง': c.heightCm > 0
                  ? '${c.heightCm.toStringAsFixed(0)} เซนติเมตร'
                  : '--',
              'อายุ': c.birthDate == null ? '--' : '${c.age} ปี',
              'ดัชนีมวลกาย (BMI)': bmi != null ? bmi.toStringAsFixed(1) : '--',
              'เป้าหมาย':
                  '${c.goalType} (${c.dailyGoal.toStringAsFixed(0)} kcal/วัน)',
            },
            highlightKeys: const {'เป้าหมาย'},
          ),
          const SizedBox(height: 24),

          PrimaryButton(
            'ออกจากระบบ',
            () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Text(
                    'ออกจากระบบ',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  content: const Text('คุณแน่ใจหรือไม่ว่าต้องการออกจากระบบ?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'ยกเลิก',
                        style: TextStyle(color: kMuted),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: kRed),
                      onPressed: () async {
                        final content = context.content;
                        final auth = context.auth;
                        try {
                          await content.logout();
                          auth.logout();
                          if (context.mounted) {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/',
                              (_) => false,
                            );
                          }
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('ออกจากระบบไม่สำเร็จ: $error'),
                                backgroundColor: kRed,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text(
                        'ยืนยัน',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
            },
            color: kRedBg,
            textColor: kRed,
            icon: Icons.logout_rounded,
          ),
        ],
      ),
    );
  }
}

class _AccountMenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _AccountMenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: kGreenBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: kGreenDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kInk,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: kMuted),
          ],
        ),
      ),
    );
  }
}

class _MealStreakCard extends StatelessWidget {
  final AppContent content;
  const _MealStreakCard({required this.content});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(7, (index) {
      final date = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: 6 - index));
      final hasMeal =
          content.mealsByDate[content.dateKey(date)]?.isNotEmpty ?? false;
      const weekdayLabels = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];
      return (
        date: date,
        hasMeal: hasMeal,
        label: weekdayLabels[date.weekday % 7],
      );
    });
    final activeDays = days.where((day) => day.hasMeal).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            activeDays == 0
                ? 'เริ่มบันทึกมื้อแรกของคุณ'
                : 'สัปดาห์นี้บันทึกอาหาร $activeDays/7 วัน',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: kGreenDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'วันที่มีรายการอาหารใน 7 วันล่าสุด',
            style: TextStyle(fontSize: 12, color: kMuted),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.map((day) {
              return Column(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: day.hasMeal ? kGreenBg : Colors.grey[100],
                      shape: BoxShape.circle,
                      border: Border.all(color: day.hasMeal ? kGreen : kBorder),
                    ),
                    child: Icon(
                      day.hasMeal ? Icons.check_rounded : Icons.close_rounded,
                      size: 16,
                      color: day.hasMeal ? kGreenDark : kMuted,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    day.label,
                    style: const TextStyle(fontSize: 10, color: kMuted),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final StringMap items;
  final Set<String> highlightKeys;
  const _InfoCard({
    required this.title,
    required this.items,
    this.highlightKeys = const {},
  });

  @override
  Widget build(BuildContext context) {
    final entries = items.entries.toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: kInk,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(entries.length, (i) {
            final e = entries[i];
            final isLast = i == entries.length - 1;
            final isHighlight = highlightKeys.contains(e.key);
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    e.key,
                    style: const TextStyle(color: kMuted, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: isHighlight
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: kGreenBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              e.value,
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: kGreenDark,
                              ),
                            ),
                          )
                        : Text(
                            e.value,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: kInk,
                            ),
                          ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_oldCtrl.text.isEmpty || _newCtrl.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'กรุณากรอกรหัสผ่านเดิมและรหัสผ่านใหม่อย่างน้อย 8 ตัวอักษร',
          ),
          backgroundColor: kRed,
        ),
      );
      return;
    }
    if (_newCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('รหัสผ่านใหม่และการยืนยันไม่ตรงกัน'),
          backgroundColor: kRed,
        ),
      );
      return;
    }
    try {
      final changed = await context.content.changePassword(
        oldPassword: _oldCtrl.text,
        newPassword: _newCtrl.text,
      );
      if (!mounted) return;
      if (!changed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('รหัสผ่านเดิมไม่ถูกต้อง'),
            backgroundColor: kRed,
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกรหัสผ่านใหม่สำเร็จแล้ว!'),
          backgroundColor: kGreen,
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('บันทึกรหัสผ่านไม่สำเร็จ: $error'),
          backgroundColor: kRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CleanAppBar(title: 'เปลี่ยนรหัสผ่าน', showBack: true),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'รหัสผ่านเดิม',
              style: TextStyle(fontWeight: FontWeight.w700, color: kInk),
            ),
            const SizedBox(height: 8),
            CleanTextField(
              hint: 'กรอกรหัสผ่านเดิม',
              obscure: true,
              controller: _oldCtrl,
            ),
            const SizedBox(height: 12),
            const Text(
              'รหัสผ่านใหม่',
              style: TextStyle(fontWeight: FontWeight.w700, color: kInk),
            ),
            const SizedBox(height: 8),
            CleanTextField(
              hint: 'กรอกรหัสผ่านใหม่ (อย่างน้อย 8 ตัวอักษร)',
              obscure: true,
              controller: _newCtrl,
            ),
            const SizedBox(height: 12),
            const Text(
              'ยืนยันรหัสผ่านใหม่',
              style: TextStyle(fontWeight: FontWeight.w700, color: kInk),
            ),
            const SizedBox(height: 8),
            CleanTextField(
              hint: 'กรอกรหัสผ่านใหม่อีกครั้ง',
              obscure: true,
              controller: _confirmCtrl,
            ),
            const Spacer(),
            PrimaryButton('บันทึกรหัสผ่านใหม่', _submit),
          ],
        ),
      ),
    );
  }
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const CleanAppBar(title: 'ตั้งค่า'),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('การแจ้งเตือน'),
          trailing: Switch(
            value: true,
            onChanged: (v) {},
            activeTrackColor: kGreen,
          ),
        ),
        const Divider(color: kBorder),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('ธีมแอปพลิเคชัน'),
          trailing: Icon(Icons.chevron_right, color: kMuted),
        ),
      ],
    ),
  );
}

// ───────────────────────── ADMIN SCREENS ─────────────────────────
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final users = context.content.users;
    final userCount = users.length;
    final foodList = context.content.adminFoods;
    final foodCount = foodList.length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'แผงควบคุมผู้ดูแลระบบ',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: kInk,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'ออกจากระบบแอดมิน',
            icon: const Icon(Icons.logout_rounded, color: kRed),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Text(
                    'ออกจากระบบผู้ดูแลระบบ',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  content: const Text(
                    'ต้องการออกจากโหมดผู้ดูแลระบบกลับไปยังหน้าเข้าสู่ระบบใช่หรือไม่?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'ยกเลิก',
                        style: TextStyle(color: kMuted),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: kRed),
                      onPressed: () {
                        context.auth.logout();
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/',
                          (_) => false,
                        );
                      },
                      child: const Text(
                        'ยืนยัน',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kGreenBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: kGreen.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.admin_panel_settings_rounded,
                          color: kGreenDark,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'ภาพรวมระบบ (Admin)',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: kInk,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: kGreen),
                          SizedBox(width: 5),
                          Text(
                            'ระบบปกติ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: kGreenDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _AdminStatBox(
                        label: 'ผู้ใช้งานทั้งหมด',
                        value: '$userCount บัญชี',
                        icon: Icons.people_alt_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AdminStatBox(
                        label: 'ฐานข้อมูลเมนู AI',
                        value: '$foodCount เมนู',
                        icon: Icons.restaurant_menu_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'เมนูการจัดการระบบ',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: kInk,
            ),
          ),
          const SizedBox(height: 12),
          _AdminMenuCard(
            title: 'จัดการบัญชีผู้ใช้ ($userCount)',
            subtitle: 'ค้นหา แก้ไขข้อมูล และรีเซ็ตรหัสผ่านผู้ใช้',
            icon: Icons.people_rounded,
            onTap: () => Navigator.pushNamed(context, '/admin/users'),
          ),
          const SizedBox(height: 14),
          _AdminMenuCard(
            title: 'จัดการฐานข้อมูลโภชนาการอาหาร ($foodCount)',
            subtitle: 'เพิ่มข้อมูลโภชนาการใหม่ และจัดการ Class AI',
            icon: Icons.fastfood_rounded,
            onTap: () => Navigator.pushNamed(context, '/admin/foods'),
          ),
        ],
      ),
    );
  }
}

class _AdminStatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _AdminStatBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kGreen, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: kInk,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: kMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminMenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _AdminMenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: kInk.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kGreenBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: kGreenDark, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: kInk,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: kMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: kMuted),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── 11. Admin Users ─────────────────────────
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final allUsers = context.content.users;
    final filtered = allUsers.entries.where((e) {
      final q = _query.toLowerCase();
      return e.key.toLowerCase().contains(q) ||
          (e.value['name'] ?? '').toLowerCase().contains(q) ||
          (e.value['email'] ?? '').toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: const CleanAppBar(title: 'จัดการบัญชีผู้ใช้', showBack: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          CleanTextField(
            hint: 'ค้นหารหัสผู้ใช้ ชื่อ หรืออีเมล',
            icon: Icons.search,
            onChanged: (v) => setState(() => _query = v),
          ),
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kBorder, width: 1.5),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.person_search_outlined,
                    size: 42,
                    color: kMuted,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'ไม่พบข้อมูลบัญชีผู้ใช้ที่ตรงกับเงื่อนไข',
                    style: TextStyle(fontWeight: FontWeight.w800, color: kInk),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => _query = ''),
                    child: const Text(
                      'แสดงผู้ใช้ทั้งหมด',
                      style: TextStyle(
                        color: kGreenDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...filtered.map(
              (entry) => _UserCard(id: entry.key, userData: entry.value),
            ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final String id;
  final StringMap userData;
  const _UserCard({required this.id, required this.userData});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder, width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: kGreenBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'ID: $id',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: kGreenDark,
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.pushNamed(
                  context,
                  '/admin/users/edit',
                  arguments: id,
                ),
                child: _outlineBtn('แก้ไข', kGreenDark, Icons.edit_outlined),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  if (context.content.users.length <= 1) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('ไม่สามารถลบบัญชีผู้ใช้สุดท้ายในระบบได้'),
                        backgroundColor: kRed,
                      ),
                    );
                    return;
                  }
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: const Text(
                        'ยืนยันการลบผู้ใช้',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      content: Text(
                        'ต้องการลบบัญชีของ "${userData['name']}" ใช่หรือไม่?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'ยกเลิก',
                            style: TextStyle(color: kMuted),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kRed,
                          ),
                          onPressed: () {
                            context.content.deleteUser(id);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('ลบบัญชีผู้ใช้เรียบร้อยแล้ว'),
                                backgroundColor: kGreen,
                              ),
                            );
                          },
                          child: const Text(
                            'ลบ',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                child: _outlineBtn('ลบ', kRed, Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ชื่อผู้ใช้ :',
                style: TextStyle(color: kMuted, fontSize: 13),
              ),
              Flexible(
                child: Text(
                  userData['name'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: kInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'อีเมล :',
                style: TextStyle(color: kMuted, fontSize: 13),
              ),
              Flexible(
                child: Text(
                  userData['email'] ?? '',
                  style: const TextStyle(
                    color: kBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _outlineBtn(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── 12. Admin Foods ─────────────────────────
class AdminFoodsScreen extends StatefulWidget {
  const AdminFoodsScreen({super.key});

  @override
  State<AdminFoodsScreen> createState() => _AdminFoodsScreenState();
}

class _AdminFoodsScreenState extends State<AdminFoodsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final foodList = context.content.adminFoods.where((f) {
      final q = _search.toLowerCase();
      return (f['name'] ?? '').toLowerCase().contains(q) ||
          (f['engName'] ?? '').toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: const CleanAppBar(title: 'จัดการโภชนาการอาหาร'),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          PrimaryButton(
            'เพิ่มข้อมูลโภชนาการอาหารใหม่',
            () => Navigator.pushNamed(context, '/admin/foods/add'),
            icon: Icons.add_circle_outline_rounded,
          ),
          const SizedBox(height: 18),
          CleanTextField(
            hint: 'ค้นหาชื่อเมนูภาษาไทย หรือ Class AI...',
            icon: Icons.search,
            onChanged: (v) => setState(() => _search = v),
          ),
          Text(
            'รายการอาหารในฐานข้อมูล (${foodList.length})',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: kInk,
            ),
          ),
          const SizedBox(height: 12),
          if (foodList.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kBorder, width: 1.5),
              ),
              child: Column(
                children: [
                  const Icon(Icons.restaurant_menu, size: 40, color: kMuted),
                  const SizedBox(height: 12),
                  const Text(
                    'ไม่พบข้อมูลอาหารที่ค้นหา',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kInk,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => _search = ''),
                    child: const Text(
                      'แสดงเมนูทั้งหมด',
                      style: TextStyle(
                        color: kGreenDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...foodList.map((item) {
              final category = item['category'] ?? 'อาหารจานเดียว';
              final serving = item['serving'] ?? '1 จาน';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kBorder, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: kGreenBg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.restaurant_menu_rounded,
                            color: kGreenDark,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: kInk,
                                ),
                              ),
                              if (item['engName'] != null &&
                                  item['engName']!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Class: ${item['engName']!} • $category',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: kMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'ลบเมนู',
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: kRed,
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: const Text(
                                  'ยืนยันการลบ',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                content: Text(
                                  'ต้องการลบเมนู "${item['name']}" หรือไม่?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text(
                                      'ยกเลิก',
                                      style: TextStyle(color: kMuted),
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: kRed,
                                    ),
                                    onPressed: () {
                                      context.content.deleteFoodByItem(item);
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'ลบข้อมูลอาหารเรียบร้อยแล้ว',
                                              ),
                                              backgroundColor: kGreen,
                                            ),
                                          );
                                    },
                                    child: const Text(
                                      'ลบ',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _InfoTag(
                          label: '${item['energy']} kcal',
                          isPrimary: true,
                        ),
                        _InfoTag(label: serving),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  final String label;
  final bool isPrimary;
  const _InfoTag({required this.label, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isPrimary ? kGreenBg : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isPrimary ? FontWeight.w800 : FontWeight.w600,
          color: isPrimary ? kGreenDark : kMuted,
        ),
      ),
    );
  }
}

// ───────────────────────── 13. Admin Add Food ─────────────────────────
class AdminAddFoodScreen extends StatefulWidget {
  const AdminAddFoodScreen({super.key});
  @override
  State<AdminAddFoodScreen> createState() => _AdminAddFoodScreenState();
}

class _AdminAddFoodScreenState extends State<AdminAddFoodScreen> {
  final _name = TextEditingController();
  final _engName = TextEditingController();
  final _serving = TextEditingController(text: '1 จาน (300 กรัม)');
  final _energy = TextEditingController();
  String _category = 'อาหารจานเดียว';

  String? _nameError;
  String? _engNameError;
  String? _energyError;

  static const _categories = [
    'อาหารจานเดียว',
    'อาหารสุขภาพ',
    'ก๋วยเตี๋ยว/เส้น',
    'ของว่าง/เครื่องดื่ม',
  ];

  @override
  void dispose() {
    _name.dispose();
    _engName.dispose();
    _serving.dispose();
    _energy.dispose();
    super.dispose();
  }

  bool _validate() {
    final name = _name.text.trim();
    final engName = _engName.text.trim();
    final energyText = _energy.text.trim();
    final parsedEnergy = double.tryParse(energyText);
    final isDuplicate = context.content.adminFoods.any(
      (f) => (f['name'] ?? '').trim().toLowerCase() == name.toLowerCase(),
    );

    setState(() {
      _nameError = name.isEmpty
          ? 'กรุณากรอกชื่ออาหาร (ภาษาไทย)'
          : (isDuplicate ? 'มีชื่อเมนูนี้ในฐานข้อมูลแล้ว กรุณาตรวจสอบ' : null);
      _engNameError = engName.isEmpty
          ? 'กรุณากรอกชื่อ Class AI (ภาษาอังกฤษ)'
          : (!RegExp(r'^[a-zA-Z0-9_ -]+$').hasMatch(engName)
                ? 'กรุณาใช้ตัวอักษรภาษาอังกฤษ ตัวเลข หรือ _ เท่านั้น'
                : null);
      _energyError = energyText.isEmpty
          ? 'กรุณากรอกพลังงาน'
          : (parsedEnergy == null
                ? 'พลังงานต้องเป็นตัวเลขเท่านั้น'
                : (parsedEnergy <= 0 || parsedEnergy > 5000
                      ? 'พลังงานต้องอยู่ระหว่าง 1 - 5,000 kcal'
                      : null));
    });

    return _nameError == null && _engNameError == null && _energyError == null;
  }

  void _save() {
    if (!_validate()) return;

    context.content.addFood({
      'name': _name.text.trim(),
      'engName': _engName.text.trim(),
      'serving': _serving.text.trim().isEmpty
          ? '1 หน่วยบริโภค'
          : _serving.text.trim(),
      'category': _category,
      'energy': _energy.text.trim(),
      'source': 'admin',
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('เพิ่มข้อมูลโภชนาการอาหารใหม่สำเร็จ'),
        backgroundColor: kGreen,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final previewName = _name.text.trim().isEmpty
        ? 'ตัวอย่างชื่อเมนูอาหาร'
        : _name.text.trim();
    final previewKcal = _energy.text.trim().isEmpty ? '0' : _energy.text.trim();

    return Scaffold(
      appBar: const CleanAppBar(title: 'เพิ่มข้อมูลโภชนาการใหม่'),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: kGreenBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: kGreen.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.restaurant_menu_rounded,
                              color: kGreenDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'พรีวิวข้อมูลโภชนาการ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: kGreenDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  previewName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: kInk,
                                  ),
                                ),
                                Text(
                                  '$_category • $previewKcal kcal',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: kMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    _FoodField(
                      label: 'ชื่ออาหาร (ภาษาไทย) *',
                      hint: 'เช่น ข้าวมันไก่ต้ม',
                      controller: _name,
                      errorText: _nameError,
                      onChanged: (_) => setState(() => _nameError = null),
                    ),
                    _FoodField(
                      label: 'ชื่อ Class AI (ภาษาอังกฤษ) *',
                      hint: 'เช่น Khao_mun_gai',
                      controller: _engName,
                      errorText: _engNameError,
                      onChanged: (_) => setState(() => _engNameError = null),
                    ),

                    const Text(
                      'หมวดหมู่อาหาร',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: kInk,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      margin: const EdgeInsets.only(bottom: 18),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kBorder, width: 1.5),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _category,
                          isExpanded: true,
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: kGreen,
                          ),
                          items: _categories.map((cat) {
                            return DropdownMenuItem(
                              value: cat,
                              child: Text(
                                cat,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: kInk,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _category = v);
                          },
                        ),
                      ),
                    ),

                    _FoodField(
                      label: 'หน่วยบริโภคมาตรฐาน',
                      hint: 'เช่น 1 จาน (300 กรัม)',
                      controller: _serving,
                    ),
                    _FoodField(
                      label: 'พลังงานรวม (กิโลแคลอรี) *',
                      hint: 'เช่น 590',
                      controller: _energy,
                      numeric: true,
                      errorText: _energyError,
                      onChanged: (_) => setState(() => _energyError = null),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: PrimaryButton(
                'บันทึกข้อมูลโภชนาการ',
                _save,
                icon: Icons.save_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool numeric;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  const _FoodField({
    required this.label,
    required this.hint,
    required this.controller,
    this.numeric = false,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: kInk,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: hasError ? kRed : kBorder, width: 1.5),
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              keyboardType: numeric
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              inputFormatters: numeric
                  ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
                  : null,
              style: const TextStyle(fontSize: 14, color: kInk),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: kMuted, fontSize: 13),
                border: InputBorder.none,
              ),
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.error_outline, size: 13, color: kRed),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    errorText!,
                    style: const TextStyle(
                      color: kRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────── 14. Admin Edit User ─────────────────────────
class AdminEditUserScreen extends StatefulWidget {
  const AdminEditUserScreen({super.key});
  @override
  State<AdminEditUserScreen> createState() => _AdminEditUserScreenState();
}

class _AdminEditUserScreenState extends State<AdminEditUserScreen> {
  TextEditingController? _name;
  TextEditingController? _email;
  final TextEditingController _resetPassword = TextEditingController();
  String _id = '';

  String? _nameError;
  String? _emailError;
  String? _passError;

  static final RegExp _emailRegex = RegExp(r'^[\w\.\+\-]+@[\w\-]+\.[\w\.\-]+$');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_name == null) {
      _id = (ModalRoute.of(context)?.settings.arguments as String?) ?? '';
      final userData = context.content.users[_id] ?? {};
      _name = TextEditingController(text: userData['name'] ?? '');
      _email = TextEditingController(text: userData['email'] ?? '');
    }
  }

  @override
  void dispose() {
    _name?.dispose();
    _email?.dispose();
    _resetPassword.dispose();
    super.dispose();
  }

  bool _validate() {
    final nameVal = _name!.text.trim();
    final emailVal = _email!.text.trim();
    final passVal = _resetPassword.text;

    final duplicateEmail = context.content.users.entries.any(
      (e) =>
          e.key != _id &&
          (e.value['email'] ?? '').toLowerCase() == emailVal.toLowerCase(),
    );

    setState(() {
      _nameError = nameVal.isEmpty ? 'กรุณากรอกชื่อ - นามสกุลผู้ใช้' : null;
      _emailError = emailVal.isEmpty
          ? 'กรุณากรอกอีเมลผู้ใช้'
          : (!_emailRegex.hasMatch(emailVal)
                ? 'รูปแบบอีเมลไม่ถูกต้อง'
                : (duplicateEmail
                      ? 'อีเมลนี้ถูกใช้งานโดยบัญชีอื่นแล้ว'
                      : null));
      _passError = (passVal.isNotEmpty && passVal.length < 8)
          ? 'รหัสผ่านใหม่ต้องมีอย่างน้อย 8 ตัวอักษร'
          : null;
    });

    return _nameError == null && _emailError == null && _passError == null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CleanAppBar(title: 'แก้ไขบัญชีผู้ใช้'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ชื่อ - นามสกุล *',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: kMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            CleanTextField(
              hint: 'ชื่อ นามสกุล',
              controller: _name,
              suffixIcon: Icons.edit_square,
              onChanged: (_) => setState(() => _nameError = null),
            ),
            if (_nameError != null) FieldError(_nameError!),

            const Text(
              'อีเมล *',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: kMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            CleanTextField(
              hint: 'อีเมล',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              suffixIcon: Icons.edit_square,
              onChanged: (_) => setState(() => _emailError = null),
            ),
            if (_emailError != null) FieldError(_emailError!),

            const Text(
              'รีเซ็ตรหัสผ่านใหม่ (ไม่บังคับ)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: kMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            CleanTextField(
              hint: 'กรอกรหัสผ่านใหม่ (อย่างน้อย 8 ตัวอักษร)',
              controller: _resetPassword,
              obscure: true,
              onChanged: (_) => setState(() => _passError = null),
            ),
            if (_passError != null) FieldError(_passError!),

            const SizedBox(height: 24),
            PrimaryButton('บันทึกข้อมูล', () {
              if (!_validate()) return;
              context.content.updateUser(_id, {
                'name': _name!.text.trim(),
                'email': _email!.text.trim(),
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _resetPassword.text.isNotEmpty
                        ? 'บันทึกข้อมูลและรีเซ็ตรหัสผ่านผู้ใช้สำเร็จ'
                        : 'บันทึกข้อมูลผู้ใช้สำเร็จ',
                  ),
                  backgroundColor: kGreen,
                ),
              );
              Navigator.pop(context);
            }),
          ],
        ),
      ),
    );
  }
}
