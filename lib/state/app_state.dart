import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../data/foods.dart';

/// มื้ออาหารที่บันทึก (แปลงจาก /api/logs)
class MealLog {
  final int logId;
  final String mealType;
  final DateTime loggedAt;
  final String foodName;
  final double grams;
  final double? calories; // null = เมนูนี้ยังไม่มีข้อมูลแคลอรี่

  MealLog({
    required this.logId,
    required this.mealType,
    required this.loggedAt,
    required this.foodName,
    required this.grams,
    required this.calories,
  });

  factory MealLog.fromJson(Map<String, dynamic> row) {
    final food = Map<String, dynamic>.from(row['foods'] ?? {});
    final per100 = toDouble(food['calories_per_100g']);
    return MealLog(
      logId: (row['log_id'] as num).toInt(),
      mealType: (row['meal_type'] ?? 'snack') as String,
      loggedAt: DateTime.tryParse('${row['logged_at']}')?.toLocal() ?? DateTime.now(),
      foodName: thaiFoodName(food['food_name'] as String?),
      grams: toDouble(row['estimated_weight']) ?? kDefaultPlateGrams,
      calories: (per100 == null || per100 <= 0) ? null : toDouble(row['total_calories']),
    );
  }
}

/// การ์ดเตือนจาก /api/dashboard/alerts
class HealthAlert {
  final String level; // danger, warning, info, good
  final String code;
  final String title;
  final String detail;
  HealthAlert(this.level, this.code, this.title, this.detail);

  factory HealthAlert.fromJson(Map<String, dynamic> j) => HealthAlert(
        '${j['level']}',
        '${j['code']}',
        '${j['title']}',
        '${j['detail']}',
      );
}

/// การออกกำลังกายที่บันทึก (จาก /api/exercise/today)
class ExerciseLog {
  final int id;
  final String activity;
  final String name;
  final int minutes;
  final double caloriesBurned;
  final DateTime loggedAt;

  ExerciseLog({
    required this.id,
    required this.activity,
    required this.name,
    required this.minutes,
    required this.caloriesBurned,
    required this.loggedAt,
  });

  factory ExerciseLog.fromJson(Map<String, dynamic> j) => ExerciseLog(
        id: (j['exercise_log_id'] as num).toInt(),
        activity: '${j['activity']}',
        name: '${j['name_th'] ?? j['activity']}',
        minutes: (j['duration_minutes'] as num?)?.toInt() ?? 0,
        caloriesBurned: toDouble(j['calories_burned']) ?? 0,
        loggedAt: DateTime.tryParse('${j['logged_at']}')?.toLocal() ?? DateTime.now(),
      );
}

/// กิจกรรมที่เลือกได้ (จาก /api/exercise/activities)
class ExerciseActivity {
  final String key;
  final String name;
  final double met;
  ExerciseActivity(this.key, this.name, this.met);

  factory ExerciseActivity.fromJson(Map<String, dynamic> j) =>
      ExerciseActivity('${j['key']}', '${j['name_th']}', toDouble(j['met']) ?? 1);
}

class DayTotal {
  final DateTime date;
  final double calories;
  DayTotal(this.date, this.calories);

  factory DayTotal.fromJson(Map<String, dynamic> j) =>
      DayTotal(DateTime.parse('${j['date']}'), toDouble(j['calories']) ?? 0);
}

/// สถานะกลางของแอป: token, ผู้ใช้, ข้อมูลส่วนตัว, มื้อวันนี้, การแจ้งเตือน
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  static const _tokenKey = 'access_token';

  final ApiClient api = ApiClient();

  Map<String, dynamic>? user;
  Map<String, dynamic>? profile;
  List<MealLog> todayMeals = [];
  List<ExerciseLog> todayExercises = [];
  List<ExerciseActivity> exerciseActivities = [];
  String? exerciseError;
  List<HealthAlert> alerts = [];
  List<DayTotal> last7 = [];
  String? dashboardError;

  bool get isLoggedIn => api.token != null && user != null;
  bool get profileComplete => profile?['is_complete'] == true;
  bool get isAdmin => (user?['role_id'] as num?)?.toInt() == 1;
  String get username => (user?['username'] ?? '') as String;
  String get email => (user?['email'] ?? '') as String;

  double? get dailyGoal => toDouble(profile?['daily_calories']);

  double get todayCalories => todayMeals.fold(0.0, (sum, m) => sum + (m.calories ?? 0));

  double get todayBurned => todayExercises.fold(0.0, (sum, e) => sum + e.caloriesBurned);

  double caloriesForMeal(String mealType) => todayMeals
      .where((m) => m.mealType == mealType)
      .fold(0.0, (sum, m) => sum + (m.calories ?? 0));

  double? get bmi {
    final w = toDouble(profile?['weight']);
    final h = toDouble(profile?['height']);
    if (w == null || h == null || h <= 0) return null;
    final m = h / 100;
    return w / (m * m);
  }

  // ---------- เริ่มแอป / ล็อกอิน ----------

  /// อ่าน token ที่เคยเก็บไว้ ถ้ายังใช้ได้ก็เข้าแอปต่อเลย
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_tokenKey);
    if (saved == null) return;
    api.token = saved;
    try {
      await refreshMe();
      await refreshToday();
    } on ApiException {
      await _clearSession();
    }
  }

  Future<void> login(String email, String password) async {
    final token = await api.login(email, password);
    await _saveToken(token);
    await refreshMe();
    await refreshToday();
  }

  Future<void> register(String username, String email, String password) async {
    await api.register(username, email, password);
    await login(email, password);
  }

  Future<void> logout() async {
    try {
      await api.logout();
    } catch (_) {
      // ออกจากระบบในเครื่องต่อ แม้เรียก API ไม่สำเร็จ
    }
    await _clearSession();
  }

  Future<void> changePassword(String current, String newPassword) async {
    final newToken = await api.changePassword(current, newPassword);
    if (newToken != null) await _saveToken(newToken);
  }

  Future<void> changeUsername(String username) async {
    await api.changeUsername(username);
    await refreshMe();
  }

  // ---------- ข้อมูล ----------

  Future<void> refreshMe() async {
    final data = await api.me();
    user = Map<String, dynamic>.from(data['user'] ?? {});
    profile = Map<String, dynamic>.from(data['profile'] ?? {});
    notifyListeners();
  }

  Future<void> saveProfile(Map<String, dynamic> fields) async {
    profile = await api.updateProfile(fields);
    notifyListeners();
    await refreshDashboard();
  }

  /// มื้อวันนี้ + การออกกำลังกาย + การแจ้งเตือน
  Future<void> refreshToday() async {
    final logs = await api.todayLogs();
    todayMeals = logs.map(MealLog.fromJson).toList();
    notifyListeners();
    await refreshExercises();
    await refreshDashboard();
  }

  /// การออกกำลังกายวันนี้ (ถ้า backend ยังไม่มีตาราง exercise_logs จะแสดงข้อความแทน ไม่ทำให้แอปพัง)
  Future<void> refreshExercises() async {
    if (isAdmin) return;
    try {
      final data = await api.todayExercises();
      todayExercises = ((data['items'] as List?) ?? [])
          .map((e) => ExerciseLog.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      exerciseError = null;
    } on ApiException catch (e) {
      exerciseError = e.message;
    }
    notifyListeners();
  }

  Future<List<ExerciseActivity>> loadExerciseActivities() async {
    if (exerciseActivities.isEmpty) {
      final data = await api.exerciseActivities();
      exerciseActivities = data.map(ExerciseActivity.fromJson).toList();
    }
    return exerciseActivities;
  }

  Future<void> addExercise(String activity, int minutes) async {
    await api.createExercise(activity, minutes);
    await refreshExercises();
    await refreshDashboard();
  }

  Future<void> deleteExercise(int id) async {
    await api.deleteExercise(id);
    await refreshExercises();
    await refreshDashboard();
  }

  Future<void> refreshDashboard() async {
    if (isAdmin || !profileComplete) return;
    try {
      final data = await api.dashboardAlerts();
      alerts = ((data['alerts'] as List?) ?? [])
          .map((e) => HealthAlert.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      last7 = ((data['last7'] as List?) ?? [])
          .map((e) => DayTotal.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      dashboardError = null;
    } on ApiException catch (e) {
      dashboardError = e.message;
    }
    notifyListeners();
  }

  Future<void> addMeal({
    required int foodId,
    required String mealType,
    required double grams,
    required bool manualWeight,
  }) async {
    await api.createLog(foodId, mealType, grams, manualWeight);
    await refreshToday();
  }

  Future<void> deleteMeal(int logId) async {
    await api.deleteLog(logId);
    await refreshToday();
  }

  Future<void> _saveToken(String token) async {
    api.token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> _clearSession() async {
    api.token = null;
    user = null;
    profile = null;
    todayMeals = [];
    todayExercises = [];
    exerciseError = null;
    alerts = [];
    last7 = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    notifyListeners();
  }
}

double? toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse('$v');
}
