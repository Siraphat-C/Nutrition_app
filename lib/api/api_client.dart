import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import '../config.dart';

/// ข้อผิดพลาดจาก backend (มีข้อความภาษาไทยให้แสดงผู้ใช้ได้เลย)
class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);

  bool get isUnauthorized => status == 401;

  @override
  String toString() => message;
}

/// เรียก API ของ backend ทุกตัว
/// ทุก response เป็น {success, message, data} ฟังก์ชันนี้คืนเฉพาะ data
class ApiClient {
  String? token;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$apiBase$path').replace(queryParameters: query);

  Map<String, String> _headers({bool json = true}) => {
        if (json) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> _send(Future<http.Response> request) async {
    http.Response res;
    try {
      res = await request.timeout(const Duration(seconds: 60));
    } catch (_) {
      throw ApiException(0, 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ตรวจสอบว่าเปิด backend อยู่ ($apiBase)');
    }
    dynamic body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      body = null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is Map && body.containsKey('data')) return body['data'];
      // backend ตอบไม่ใช่รูปแบบ {success, message, data} = โค้ด backend คนละรุ่น
      throw ApiException(res.statusCode, 'เซิร์ฟเวอร์ตอบผิดรูปแบบ ตรวจสอบว่ารัน backend จาก branch backend-dev');
    }
    throw ApiException(res.statusCode, _errorMessage(res.statusCode, body));
  }

  String _errorMessage(int status, dynamic body) {
    if (body is Map) {
      final detail = body['detail'] ?? body['message'];
      if (detail is String) return detail;
      // 422 จาก FastAPI: detail เป็น list ของ error แต่ละช่อง
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) {
          final loc = first['loc'];
          final field = loc is List && loc.isNotEmpty ? loc.last.toString() : '';
          return 'ข้อมูลไม่ถูกต้อง${field.isEmpty ? '' : ' ($field)'}: ${first['msg']}';
        }
      }
    }
    if (status == 401) return 'กรุณาเข้าสู่ระบบใหม่';
    return 'เกิดข้อผิดพลาด ($status)';
  }

  Future<dynamic> get(String path, [Map<String, String>? query]) =>
      _send(http.get(_uri(path, query), headers: _headers(json: false)));

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) =>
      _send(http.post(_uri(path), headers: _headers(), body: jsonEncode(body ?? {})));

  Future<dynamic> put(String path, Map<String, dynamic> body) =>
      _send(http.put(_uri(path), headers: _headers(), body: jsonEncode(body)));

  // ---------- บัญชีผู้ใช้ ----------

  Future<void> register(String username, String email, String password) =>
      post('/api/register', {'username': username, 'email': email, 'password': password});

  /// คืน access_token
  Future<String> login(String email, String password) async {
    final data = await post('/api/login', {'email': email, 'password': password});
    return data['access_token'] as String;
  }

  /// {user: {...}, profile: {...}}
  Future<Map<String, dynamic>> me() async =>
      Map<String, dynamic>.from(await get('/api/me'));

  Future<void> logout() => post('/api/logout');

  /// เปลี่ยนรหัสผ่าน คืน token ใหม่ (token เก่าใช้ไม่ได้แล้ว)
  Future<String?> changePassword(String current, String newPassword) async {
    final data = await put('/api/account', {'current_password': current, 'new_password': newPassword});
    return data is Map ? data['access_token'] as String? : null;
  }

  Future<void> changeUsername(String username) => put('/api/account', {'username': username});

  // ---------- ข้อมูลส่วนตัว ----------

  Future<Map<String, dynamic>> getProfile() async =>
      Map<String, dynamic>.from(await get('/api/profile'));

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> fields) async =>
      Map<String, dynamic>.from(await put('/api/profile', fields));

  /// {bmr, tdee, daily_calories, bmi, allowed_goals, expected_kg_per_week, expected_kg_per_month} ยังไม่บันทึก
  Future<Map<String, dynamic>> previewRequirement(Map<String, dynamic> fields) async =>
      Map<String, dynamic>.from(await post('/api/profile/preview', fields));

  // ---------- อาหาร ----------

  /// {food_name, confidence, food_id, calories_per_100g}
  Future<Map<String, dynamic>> analyze(Uint8List bytes, String filename) async {
    final request = http.MultipartRequest('POST', _uri('/api/analyze'))
      ..headers.addAll(_headers(json: false))
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: _imageType(filename),
      ));
    final data = await _send(request.send().then(http.Response.fromStream));
    return Map<String, dynamic>.from(data);
  }

  static MediaType _imageType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    return MediaType('image', 'jpeg');
  }

  Future<List<Map<String, dynamic>>> foods() async {
    final data = await get('/api/foods', {'limit': '100'});
    return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// บันทึกมื้อ (weight = กรัม) คืนมื้อที่บันทึก มี log_id และ total_calories
  Future<Map<String, dynamic>> createLog(int foodId, String mealType, double weight, bool isManualWeight) async =>
      Map<String, dynamic>.from(await post('/api/logs', {
        'food_id': foodId,
        'meal_type': mealType,
        'weight': weight,
        'is_manual_weight': isManualWeight,
      }));

  Future<void> deleteLog(int logId) => _send(
      http.delete(_uri('/api/logs/$logId'), headers: _headers(json: false)));

  Future<List<Map<String, dynamic>>> todayLogs() async {
    final data = await get('/api/logs/today');
    return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // ---------- ออกกำลังกาย ----------

  /// [{key, name_th, met, compendium_code}]
  Future<List<Map<String, dynamic>>> exerciseActivities() async {
    final data = await get('/api/exercise/activities');
    return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// บันทึกการออกกำลังกาย คืนรายการที่บันทึก มี calories_burned
  Future<Map<String, dynamic>> createExercise(String activity, int minutes) async =>
      Map<String, dynamic>.from(await post('/api/exercise', {'activity': activity, 'minutes': minutes}));

  /// {items: [...], total_burned}
  Future<Map<String, dynamic>> todayExercises() async =>
      Map<String, dynamic>.from(await get('/api/exercise/today'));

  Future<void> deleteExercise(int id) =>
      _send(http.delete(_uri('/api/exercise/$id'), headers: _headers(json: false)));

  // ---------- Dashboard / น้ำหนัก ----------

  /// {goal, alerts: [{level, code, title, detail}], last7: [{date, calories (สุทธิ), eaten, burned}]}
  Future<Map<String, dynamic>> dashboardAlerts() async =>
      Map<String, dynamic>.from(await get('/api/dashboard/alerts'));

  /// month = "2026-11"
  Future<Map<String, dynamic>> dashboardSummary(String month) async =>
      Map<String, dynamic>.from(await get('/api/dashboard/summary', {'month': month}));

  // ---------- แอดมิน ----------

  /// {admin, stats: {total_users, total_admins, total_foods}}
  Future<Map<String, dynamic>> adminDashboard() async =>
      Map<String, dynamic>.from(await get('/api/admin/dashboard'));

  /// q = ค้นหาจาก username หรืออีเมล
  Future<List<Map<String, dynamic>>> adminUsers({String? q}) async {
    final data = await get('/api/admin/users', {
      'limit': '100',
      if (q != null && q.isNotEmpty) 'q': q,
    });
    return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> adminCreateUser(Map<String, dynamic> fields) => post('/api/admin/users', fields);

  Future<void> adminUpdateUser(int userId, Map<String, dynamic> fields) => put('/api/admin/users/$userId', fields);

  Future<void> adminDeleteUser(int userId) =>
      _send(http.delete(_uri('/api/admin/users/$userId'), headers: _headers(json: false)));

  Future<void> adminCreateFood(String name, double caloriesPer100g) =>
      post('/api/admin/foods', {'food_name': name, 'calories_per_100g': caloriesPer100g});

  Future<void> adminUpdateFood(int foodId, Map<String, dynamic> fields) => put('/api/admin/foods/$foodId', fields);

  Future<void> adminDeleteFood(int foodId) =>
      _send(http.delete(_uri('/api/admin/foods/$foodId'), headers: _headers(json: false)));

  /// [{weight_log_id, weight, logged_at}]
  Future<List<Map<String, dynamic>>> weightHistory({int days = 90}) async {
    final data = await get('/api/weight/history', {'days': '$days'});
    return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
