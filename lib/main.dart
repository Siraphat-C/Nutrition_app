import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';

// ───────────────────────── Type Definitions ─────────────────────────
typedef StringMap = Map<String, String>;
typedef DynamicMap = Map<String, dynamic>;

// ───────────────────────── Theme Colors ─────────────────────────
const kGreen = Color(0xFF20C96A);
const kGreenDark = Color(0xFF0E9F55);
const kGreenBg = Color(0xFFE8F8EF);
const kInk = Color(0xFF1E293B);
const kMuted = Color(0xFF64748B);
const kBorder = Color(0xFFF1F5F9);
const kRed = Color(0xFFFF4D4F);
const kRedBg = Color(0xFFFFF1F0);
const kBlue = Color(0xFF4285F4);
const kOrange = Color(0xFFFBBC05);

// รายชื่อกล้องที่เครื่องรองรับ (ใช้โดย CaptureScreen)
List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (_) {
    cameras = [];
  }
  runApp(const NutritionApp());
}

// ───────────────────────── Admin Auth State ─────────────────────────
class AdminAuth extends ChangeNotifier {
  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;

  bool login(String email, String password) {
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
  final Map<String, StringMap> users = {
    '6701': {'name': 'แคทเธอรีน ภูชาง', 'email': 'Doradaymon@gmail.com', 'role': 'ผู้ใช้งาน'},
    '6702': {'name': 'ปิติโชค โดราเอม่อน', 'email': 'user2@gmail.com', 'role': 'ผู้ใช้งาน'},
    '6703': {'name': 'มะม่วง ใจดี', 'email': 'user3@gmail.com', 'role': 'ผู้ใช้งาน'},
  };

  final List<StringMap> foods = [
    {'name': 'ข้าวมันไก่ต้ม', 'engName': 'Khao_mun_gai', 'energy': '590', 'source': 'admin'},
    {'name': 'สุกี้น้ำรวมมิตร', 'engName': 'Suki_nam_ruam_mit', 'energy': '320', 'source': 'admin'},
  ];

  final Map<String, List<DynamicMap>> mealsByDate = {};

  DateTime selectedDate = DateTime.now();
  DateTime? birthDate = DateTime(1997, 3, 14);
  String fullName = 'แคทเธอรีน ภูชาง';
  String email = 'Doradaymon@gmail.com';
  double weightKg = 55.0;
  double heightCm = 165.0;
  String gender = 'หญิง';
  String activityLevel = 'ปานกลาง (ออกกำลังกายสม่ำเสมอ)';
  String goalType = 'รักษาน้ำหนัก';
  
  double get dailyGoal => calculateRecommendedTDEE();

  AppContent() {
    final todayKey = dateKey(DateTime.now());
    mealsByDate[todayKey] = [
      {
        'id': 'm1',
        'name': 'ข้าวกระเพราหมูสับไข่ดาว',
        'calories': 540.0,
        'time': '12:15',
      },
    ];
  }

  String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<DynamicMap> get currentMeals => mealsByDate[dateKey(selectedDate)] ?? [];

  double get totalDailyCalories =>
      currentMeals.fold(0.0, (sum, item) => sum + (item['calories'] as double));

  int get age {
    if (birthDate == null) return 24;
    final now = DateTime.now();
    int a = now.year - birthDate!.year;
    if (now.month < birthDate!.month || (now.month == birthDate!.month && now.day < birthDate!.day)) {
      a--;
    }
    return a.clamp(1, 120);
  }

  double calculateRecommendedTDEE({String? forGoal, String? forActivity}) {
    final String actLevel = forActivity ?? activityLevel;
    final String gType = forGoal ?? goalType;
    final double bmr = gender == 'ชาย'
        ? (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5
        : (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;

    double multiplier = 1.375;
    if (actLevel.contains('น้อย')) multiplier = 1.2;
    if (actLevel.contains('ปานกลาง')) multiplier = 1.55;
    if (actLevel.contains('หนัก')) multiplier = 1.725;

    double tdee = bmr * multiplier;
    if (gType.contains('ลดน้ำหนัก')) tdee -= 400;
    if (gType.contains('เพิ่มน้ำหนัก')) tdee += 400;

    return tdee.clamp(1200, 4000).roundToDouble();
  }

  void startNewAccount({required String name, required String newEmail}) {
    fullName = name;
    email = newEmail;
    birthDate = null;
    weightKg = 0;
    heightCm = 0;
    gender = 'หญิง';
    activityLevel = 'ปานกลาง (ออกกำลังกายสม่ำเสมอ)';
    goalType = 'รักษาน้ำหนัก';
    mealsByDate.clear();
    selectedDate = DateTime.now();
    notifyListeners();
  }

  void setSelectedDate(DateTime date) {
    selectedDate = date;
    notifyListeners();
  }

  void updateAccountInfo({
    String? name,
    String? newEmail,
    DateTime? newBirthDate,
  }) {
    if (name != null && name.isNotEmpty) fullName = name;
    if (newEmail != null && newEmail.isNotEmpty) email = newEmail;
    if (newBirthDate != null) birthDate = newBirthDate;
    notifyListeners();
  }

  void updateHealthProfile({
    double? weight,
    double? height,
    String? userGender,
    String? activity,
    String? targetType,
  }) {
    if (weight != null) weightKg = weight;
    if (height != null) heightCm = height;
    if (userGender != null) gender = userGender;
    if (activity != null) activityLevel = activity;
    if (targetType != null) goalType = targetType;
    notifyListeners();
  }

  void logMeal({
    required String name,
    required double calories,
    TimeOfDay? customTime,
  }) {
    final t = customTime ?? TimeOfDay.now();
    final timeStr = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final key = dateKey(selectedDate);
    mealsByDate.putIfAbsent(key, () => []);
    mealsByDate[key]!.insert(0, {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'name': name,
      'calories': calories,
      'time': timeStr,
    });
    notifyListeners();
  }

  void deleteMeal(String id) {
    final key = dateKey(selectedDate);
    mealsByDate[key]?.removeWhere((m) => m['id'] == id);
    notifyListeners();
  }

  List<StringMap> get adminFoods =>
      foods.where((f) => f['source'] == 'admin').toList();

  void addFood(StringMap foodData) {
    foods.add(foodData);
    notifyListeners();
  }

  void updateFoodAt(int index, StringMap newFoodData) {
    if (index >= 0 && index < foods.length) {
      foods[index] = newFoodData;
      notifyListeners();
    }
  }

  void deleteFoodAt(int index) {
    if (index >= 0 && index < foods.length) {
      foods.removeAt(index);
      notifyListeners();
    }
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
class NutritionApp extends StatefulWidget {
  const NutritionApp({super.key});
  @override
  State<NutritionApp> createState() => _NutritionAppState();
}

class _NutritionAppState extends State<NutritionApp> {
  final _auth = AdminAuth();
  final _content = AppContent();

  @override
  Widget build(BuildContext context) {
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
            colorScheme: ColorScheme.fromSeed(seedColor: kGreen, primary: kGreen),
            useMaterial3: true,
          ),
          initialRoute: '/',
          routes: {
            '/': (_) => const IntroScreen(),
            '/register': (_) => const RegisterScreen(),
            '/dob': (_) => const DobScreen(),
            '/health': (_) => const HealthScreen(),
            '/goal': (_) => const GoalScreen(),
            '/home': (_) => const DashboardScreen(),
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
            '/admin/foods/edit': (_) => const AdminEditFoodScreen(),
          },
        ),
      ),
    );
  }
}

// ───────────────────────── InheritedWidget Providers ─────────────────────────
class _Providers extends InheritedWidget {
  final AdminAuth auth;
  final AppContent content;
  const _Providers({required this.auth, required this.content, required super.child});

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

// ───────────────────────── Shared Widgets ─────────────────────────
class CleanAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBack;
  const CleanAppBar({super.key, this.title = '', this.showBack = true});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kInk)),
      leading: showBack
          ? Padding(
              padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
              child: InkWell(
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.arrow_back_ios_new, size: 16, color: kInk),
                ),
              ),
            )
          : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(60);
}

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color color;
  final Color textColor;
  const PrimaryButton(this.text, this.onTap, {super.key, this.color = kGreen, this.textColor = Colors.white});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: onTap,
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class CleanTextField extends StatelessWidget {
  final String hint;
  final IconData? icon;
  final IconData? suffixIcon;
  final bool obscure;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const CleanTextField({
    super.key,
    required this.hint,
    this.icon,
    this.suffixIcon,
    this.obscure = false,
    this.controller,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder, width: 1.5),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: kMuted, fontSize: 14),
          prefixIcon: icon != null ? Icon(icon, color: kMuted) : null,
          suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: kMuted, size: 18) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}

class FieldError extends StatelessWidget {
  final String message;
  const FieldError(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: -8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 14, color: kRed),
          const SizedBox(width: 6),
          Expanded(child: Text(message, style: const TextStyle(color: kRed, fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class BaseNavLayout extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  const BaseNavLayout({super.key, required this.body, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: body),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: kBorder, width: 1))),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          elevation: 0,
          currentIndex: currentIndex,
          selectedItemColor: kGreen,
          unselectedItemColor: kMuted,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          onTap: (i) {
            if (i == currentIndex) return;
            if (i == 0) Navigator.pushReplacementNamed(context, '/home');
            if (i == 1) Navigator.pushReplacementNamed(context, '/capture');
            if (i == 2) Navigator.pushReplacementNamed(context, '/profile');
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'หน้าหลัก'),
            BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline, size: 28), label: 'สแกนอาหาร'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'โปรไฟล์'),
          ],
        ),
      ),
    );
  }
}

Future<bool> showAdminLoginDialog(BuildContext context) async {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  var error = '';

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('เข้าสู่ระบบผู้ดูแลระบบ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'อีเมล', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'รหัสผ่าน', border: OutlineInputBorder()),
            ),
            if (error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(error, style: const TextStyle(color: kRed, fontSize: 12)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kGreen),
            onPressed: () {
              final auth = _Providers.of(context).auth;
              if (auth.login(emailCtrl.text.trim(), passCtrl.text)) {
                Navigator.pop(ctx, true);
              } else {
                setState(() => error = 'ข้อมูลเข้าสู่ระบบไม่ถูกต้อง');
              }
            },
            child: const Text('เข้าสู่ระบบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

// ───────────────────────── 1. Login / Intro ─────────────────────────
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                const CircleAvatar(radius: 50, backgroundColor: kGreenBg, child: Icon(Icons.restaurant, size: 50, color: kGreen)),
                const SizedBox(height: 24),
                const Text('วิเคราะห์โภชนาการ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('แอปพลิเคชันวิเคราะห์โภชนาการอาหาร\nจากรูปภาพด้วยปัญญาประดิษฐ์', style: TextStyle(color: kMuted), textAlign: TextAlign.center),
                const Spacer(),
                const CleanTextField(hint: 'อีเมล', icon: Icons.email_outlined),
                const CleanTextField(hint: 'รหัสผ่าน', icon: Icons.lock_outline, obscure: true),
                const SizedBox(height: 8),
                PrimaryButton('เข้าสู่ระบบ', () => Navigator.pushReplacementNamed(context, '/home')),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  child: const Text('สมัครสมาชิกใหม่', style: TextStyle(color: kMuted)),
                ),
                TextButton(
                  onPressed: () async {
                    final ok = await showAdminLoginDialog(context);
                    if (ok && context.mounted) {
                      Navigator.pushReplacementNamed(context, '/admin/home');
                    }
                  },
                  child: const Text('เข้าสู่ระบบสำหรับผู้ดูแลระบบ', style: TextStyle(color: kGreen)),
                ),
              ],
            ),
          ),
        ),
      );
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
          : (!_emailRegex.hasMatch(email) ? 'รูปแบบอีเมลไม่ถูกต้อง เช่น name@example.com' : null);
      _passwordError = password.isEmpty
          ? 'กรุณากรอกรหัสผ่าน'
          : (password.length < 8 ? 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร' : null);
    });

    return _nameError == null && _emailError == null && _passwordError == null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const CleanAppBar(title: 'สมัครสมาชิก'),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              CleanTextField(hint: 'ชื่อ - นามสกุล', controller: _nameCtrl),
              if (_nameError != null) FieldError(_nameError!),
              CleanTextField(hint: 'อีเมล', controller: _emailCtrl, keyboardType: TextInputType.emailAddress),
              if (_emailError != null) FieldError(_emailError!),
              CleanTextField(hint: 'รหัสผ่าน', controller: _passwordCtrl, obscure: true),
              if (_passwordError != null) FieldError(_passwordError!),
              const Spacer(),
              PrimaryButton('ถัดไป', () {
                if (_validate()) {
                  context.content.startNewAccount(
                    name: _nameCtrl.text.trim(),
                    newEmail: _emailCtrl.text.trim(),
                  );
                  Navigator.pushNamed(context, '/dob');
                }
              }),
            ],
          ),
        ),
      );
}

// ───────────────────────── 3. Health Information ─────────────────────────
class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  String _selectedGender = 'หญิง';
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _selectedGender = context.content.gender;
      _weightCtrl.text = context.content.weightKg > 0 ? context.content.weightKg.toStringAsFixed(1) : '';
      _heightCtrl.text = context.content.heightCm > 0 ? context.content.heightCm.toStringAsFixed(0) : '';
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
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    final hMeter = h / 100;
    return w / (hMeter * hMeter);
  }

  Map<String, dynamic> _bmiStatus(double bmi) {
    if (bmi < 18.5) {
      return {'label': 'น้ำหนักน้อย / ผอม', 'color': kBlue, 'bg': kGreenBg};
    } else if (bmi < 23.0) {
      return {'label': 'สมส่วน (สุขภาพดี)', 'color': kGreen, 'bg': kGreenBg};
    } else if (bmi < 25.0) {
      return {'label': 'น้ำหนักเกิน (ท้วม)', 'color': kOrange, 'bg': kGreenBg};
    } else {
      return {'label': 'โรคอ้วน (ควรควบคุม)', 'color': kRed, 'bg': kRedBg};
    }
  }

  void _onContinue() {
    final w = double.tryParse(_weightCtrl.text.trim());
    final h = double.tryParse(_heightCtrl.text.trim());

    if (w == null || w <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกน้ำหนักปัจจุบันให้ถูกต้อง'), backgroundColor: kRed),
      );
      return;
    }

    if (h == null || h <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกส่วนสูงให้ถูกต้อง'), backgroundColor: kRed),
      );
      return;
    }

    context.content.updateHealthProfile(
      userGender: _selectedGender,
      weight: w,
      height: h,
    );
    Navigator.pushNamed(context, '/goal');
  }

  Widget _genderOption(String label, IconData icon) {
    final isSelected = _selectedGender == label;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedGender = label),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? kGreenBg : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? kGreen : kBorder,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? kGreenDark : kMuted,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
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

    return Scaffold(
      appBar: const CleanAppBar(title: 'ข้อมูลสุขภาพ'),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(Icons.monitor_heart_outlined, size: 44, color: kGreen),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'ข้อมูลสุขภาพของคุณ',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kInk),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'เพศ วันเกิด และน้ำหนักปัจจุบันจะถูกนำไปใช้คำนวณแผนโภชนาการที่เหมาะสมสำหรับคุณ',
                      style: TextStyle(color: kMuted),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: kGreenBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cake_outlined, size: 20, color: kGreenDark),
                          const SizedBox(width: 10),
                          Text(
                            'วันเกิด: $birthDateLabel',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: kInk),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('เพศ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kInk)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _genderOption('ชาย', Icons.male),
                        const SizedBox(width: 12),
                        _genderOption('หญิง', Icons.female),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('น้ำหนักปัจจุบัน (กิโลกรัม)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kInk)),
                    const SizedBox(height: 8),
                    CleanTextField(
                      hint: 'เช่น 58.5',
                      icon: Icons.monitor_weight_outlined,
                      controller: _weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                    const Text('ส่วนสูง (เซนติเมตร)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kInk)),
                    const SizedBox(height: 8),
                    CleanTextField(
                      hint: 'เช่น 165',
                      icon: Icons.height,
                      controller: _heightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (currentBmi != null) ...[
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final status = _bmiStatus(currentBmi);
                          final Color statusColor = status['color'] as Color;
                          final Color statusBg = status['bg'] as Color;
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('ดัชนีมวลกาย (BMI)', style: TextStyle(fontSize: 12, color: kMuted)),
                                    const SizedBox(height: 4),
                                    Text(
                                      currentBmi.toStringAsFixed(1),
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kInk),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    status['label'] as String,
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton('ถัดไป', _onContinue),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 4. Goals ─────────────────────────
class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key});
  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  String _selectedTarget = 'รักษาน้ำหนัก';
  String _selectedActivity = 'ปานกลาง (ออกกำลังกายสม่ำเสมอ)';
  bool _initialized = false;

  final List<String> _targetOptions = [
    'ลดน้ำหนัก',
    'รักษาน้ำหนัก',
    'เพิ่มน้ำหนัก',
  ];

  final List<String> _activityOptions = [
    'น้อย (ไม่ออกกำลังกาย)',
    'ปานกลาง (ออกกำลังกายสม่ำเสมอ)',
    'หนัก (ออกกำลังกายหนักทุกวัน)',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _selectedTarget = _targetOptions.contains(context.content.goalType)
          ? context.content.goalType
          : _targetOptions[1];
      _selectedActivity = _activityOptions.contains(context.content.activityLevel)
          ? context.content.activityLevel
          : _activityOptions[1];
      _initialized = true;
    }
  }

  void _updateAutoRecommendation() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final calculatedGoal = context.content.calculateRecommendedTDEE(
      forGoal: _selectedTarget,
      forActivity: _selectedActivity,
    );

    return Scaffold(
      appBar: const CleanAppBar(title: 'เป้าหมายของคุณ'),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('เป้าหมายสุขภาพ', style: TextStyle(fontWeight: FontWeight.bold, color: kInk)),
              const SizedBox(height: 10),
              _buildDropdown<String>(
                value: _selectedTarget,
                items: _targetOptions,
                labelOf: (v) => v,
                onChanged: (val) {
                  if (val != null) {
                    _selectedTarget = val;
                    _updateAutoRecommendation();
                  }
                },
              ),
              const SizedBox(height: 16),

              const Text('ระดับกิจกรรม', style: TextStyle(fontWeight: FontWeight.bold, color: kInk)),
              const SizedBox(height: 10),
              _buildDropdown<String>(
                value: _selectedActivity,
                items: _activityOptions,
                labelOf: (v) => v,
                onChanged: (val) {
                  if (val != null) {
                    _selectedActivity = val;
                    _updateAutoRecommendation();
                  }
                },
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kGreenBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kGreen.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Text('พลังงานที่แนะนำสำหรับคุณ', style: TextStyle(fontSize: 14, color: kMuted, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      '${calculatedGoal.toStringAsFixed(0)} kcal / วัน',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kGreenDark),
                    ),
                    const SizedBox(height: 8),
                    const Text('ระบบคำนวณให้จากเป้าหมายและระดับกิจกรรมของคุณอัตโนมัติ', 
                        textAlign: TextAlign.center, 
                        style: TextStyle(fontSize: 11, color: kMuted)),
                  ],
                ),
              ),

              const Spacer(),
              PrimaryButton('บันทึกและเสร็จสิ้น', () {
                context.content.updateHealthProfile(
                  targetType: _selectedTarget,
                  activity: _selectedActivity,
                );
                Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required String Function(T) labelOf,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: kGreen),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(labelOf(item), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kInk)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
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
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final totalCal = context.content.totalDailyCalories;
    final goalCal = context.content.dailyGoal;
    final percent = goalCal > 0 ? ((totalCal / goalCal) * 100).round() : 0;
    final progress = goalCal > 0 ? (totalCal / goalCal).clamp(0.0, 1.0) : 0.0;
    final isOver = totalCal > goalCal;
    final isGoalReached = !isOver && goalCal > 0 && (goalCal - totalCal).abs() < 1;
    final remainingCal = (goalCal - totalCal).abs();
    final meals = context.content.currentMeals;

    return BaseNavLayout(
      currentIndex: 0,
      body: RefreshIndicator(
        color: kGreen,
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 800));
        },
        child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: context.content.selectedDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null && context.mounted) {
                    context.content.setSelectedDate(picked);
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: kInk),
                      const SizedBox(width: 8),
                      Text(_formatDateLabel(context.content.selectedDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Icon(Icons.keyboard_arrow_down, size: 18),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () => Navigator.pushNamed(context, '/goal'),
                child: const Icon(Icons.tune, color: kMuted),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Main Calorie Circle Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isGoalReached ? kGreen : kBorder,
                width: 1.5,
              ),
              boxShadow: [BoxShadow(color: (isOver ? kRed : kGreen).withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: Column(
              children: [
                SizedBox(
                  width: 190,
                  height: 190,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 190,
                        height: 190,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 16,
                          strokeCap: StrokeCap.round,
                          backgroundColor: isOver ? kRedBg : kGreenBg,
                          color: isOver ? kRed : (isGoalReached ? kGreenDark : kGreen),
                        ),
                      ),
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: isOver ? kRedBg : kGreenBg),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('$percent%', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: kInk)),
                            const SizedBox(height: 2),
                            Text('จาก ${goalCal.toStringAsFixed(0)} kcal', style: const TextStyle(fontSize: 13, color: kMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('พลังงานสะสมวันนี้', style: TextStyle(color: kMuted, fontSize: 14)),
                const SizedBox(height: 4),
                Text('${totalCal.toStringAsFixed(0)} kcal', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kInk)),
                const SizedBox(height: 4),
                Text(
                  isOver
                      ? 'เกินเป้าหมาย ${remainingCal.toStringAsFixed(0)} kcal'
                      : isGoalReached
                          ? 'ครบตามเป้าหมายที่กำหนดไว้แล้ว'
                          : 'เหลืออีก ${remainingCal.toStringAsFixed(0)} kcal',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isOver ? kRed : (isGoalReached ? kGreenDark : kMuted),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isOver ? kRedBg : kGreenBg,
                    borderRadius: BorderRadius.circular(20),
                    border: isGoalReached ? Border.all(color: kGreen, width: 1) : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOver
                            ? Icons.warning_amber_rounded
                            : isGoalReached
                                ? Icons.check_circle
                                : Icons.circle,
                        size: isOver || isGoalReached ? 14 : 8,
                        color: isOver ? kRed : (isGoalReached ? kGreenDark : kGreen),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          isOver
                              ? 'พลังงานเกินเป้าหมายรายวันแล้ว'
                              : isGoalReached
                                  ? 'ยินดีด้วย! ถึงเป้าหมายรายวันแล้ว'
                                  : 'อยู่ในเกณฑ์เป้าหมายรายวัน',
                          style: TextStyle(
                            fontSize: 12,
                            color: isOver ? kRed : (isGoalReached ? kGreenDark : kGreen),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ประวัติการรับประทานอาหาร', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${meals.length} รายการ', style: const TextStyle(fontSize: 12, color: kMuted)),
            ],
          ),
          const SizedBox(height: 16),

          if (meals.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: kBorder)),
              child: const Center(
                child: Text('ยังไม่มีบันทึกอาหารในวันนี้ กดปุ่มสแกนอาหารด้านล่างเพื่อเริ่มต้น', style: TextStyle(color: kMuted, fontSize: 13)),
              ),
            )
          else
            ...meals.map((meal) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: kBorder)),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(color: kGreenBg, borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.restaurant, color: kGreen),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(meal['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(
                              'พลังงาน ${(meal['calories'] as double).toStringAsFixed(0)} kcal • เวลา ${meal['time']} น.',
                              style: const TextStyle(fontSize: 12, color: kMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
        ],
        ),
      ),
    );
  }
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
      _controller = CameraController(cameras.first, ResolutionPreset.medium, enableAudio: false);
      _initFuture = _controller!.initialize();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบกล้องบนอุปกรณ์นี้'), backgroundColor: kRed),
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
        const SnackBar(content: Text('อุปกรณ์นี้ไม่รองรับแฟลช'), backgroundColor: kRed),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null || !mounted) return;
      final imageBytes = await picked.readAsBytes();
      if (!mounted) return;
      Navigator.pushNamed(context, '/analysis', arguments: imageBytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถเปิดคลังภาพได้ กรุณาตรวจสอบสิทธิ์การเข้าถึง'), backgroundColor: kRed),
        );
      }
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
      if (mounted) {
        Navigator.pushNamed(context, '/analysis', arguments: imageBytes);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ถ่ายภาพไม่สำเร็จ กรุณาลองใหม่อีกครั้ง'), backgroundColor: kRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseNavLayout(
      currentIndex: 1,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  decoration: BoxDecoration(color: Colors.grey[50], border: Border.all(color: kBorder)),
                  child: _controller == null
                      ? const Center(child: Icon(Icons.camera_alt, size: 64, color: Colors.grey))
                      : FutureBuilder<void>(
                          future: _initFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.done) {
                              if (snapshot.hasError) {
                                return const Center(
                                  child: Text(
                                    'ไม่สามารถเริ่มต้นกล้องได้',
                                    style: TextStyle(color: kMuted),
                                  ),
                                );
                              }
                              return SizedBox.expand(child: CameraPreview(_controller!));
                            }
                            return const Center(child: CircularProgressIndicator(color: kGreen));
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    InkWell(
                      onTap: _pickFromGallery,
                      borderRadius: BorderRadius.circular(28),
                      child: CircleAvatar(radius: 28, backgroundColor: Colors.grey[100], child: const Icon(Icons.photo, color: kInk)),
                    ),
                    const SizedBox(height: 8),
                    const Text('คลังภาพ', style: TextStyle(fontSize: 12)),
                  ],
                ),
                InkWell(
                  onTap: _isCapturing ? null : _capturePhoto,
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: kGreen,
                    child: _isCapturing
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Icon(Icons.camera_alt, color: Colors.white, size: 32),
                  ),
                ),
                Column(
                  children: [
                    InkWell(
                      onTap: _toggleFlash,
                      borderRadius: BorderRadius.circular(28),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: _flashOn ? kGreenBg : Colors.grey[100],
                        child: Icon(_flashOn ? Icons.flash_on : Icons.flash_off, color: _flashOn ? kGreenDark : kInk),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('แฟลช', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── 7. Analysis ─────────────────────────
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  int _selectedMenuIndex = 0;
  double _portionMultiplier = 1.0;
  TimeOfDay _selectedTime = TimeOfDay.now();

  bool _isAnalyzing = true;
  Uint8List? _imageBytes;
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
      _imageBytes = ModalRoute.of(context)?.settings.arguments as Uint8List?;
      _argsRead = true;
    }
  }

  Future<void> _startAnalysis() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) setState(() => _isAnalyzing = false);
  }

  final List<DynamicMap> _aiPredictions = [
    {
      'name': 'ข้าวกระเพราหมูสับไข่ดาว',
      'confidence': 94.8,
      'calories': 540.0,
      'depthCm': 3.4,
      'weightGrams': 285,
      'missingInsight': 'มื้อนี้เน้นคาร์โบไฮเดรตและไขมันสูง แต่ยังขาดใยอาหารและวิตามิน แนะนำเสริมผักสดหรือผลไม้ไม่หวานในมื้อถัดไป',
    },
    {
      'name': 'ข้าวหมูกระเทียมไข่ดาว',
      'confidence': 4.1,
      'calories': 520.0,
      'depthCm': 3.1,
      'weightGrams': 270,
      'missingInsight': 'มื้อนี้ยังขาดผักใบเขียวและกากใยอาหาร แนะนำเพิ่มต้มจืดผักกาดขาวหรือแตงกวาเพื่อสมดุลทางโภชนาการ',
    },
    {
      'name': 'ข้าวผัดหมูใส่ไข่',
      'confidence': 1.1,
      'calories': 560.0,
      'depthCm': 3.8,
      'weightGrams': 310,
      'missingInsight': 'พลังงานหลักมาจากข้าวผัดน้ำมัน ควรเพิ่มโปรตีนไม่ติดมันหรือผักเพิ่มในมื้อเย็นเพื่อไม่ให้เกินเป้าหมาย',
    },
  ];

  void _showCustomFoodDialog() {
    final currentFood = _aiPredictions[_selectedMenuIndex];
    final nameCtrl = TextEditingController(text: currentFood['name'] as String);
    final calCtrl = TextEditingController(text: (currentFood['calories'] as double).toStringAsFixed(0));

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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('แก้ไขชื่อ / พลังงานอาหาร', style: TextStyle(fontWeight: FontWeight.bold, color: kInk)),
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
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก', style: TextStyle(color: kMuted))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kGreen),
                onPressed: trySave,
                child: const Text('บันทึกการแก้ไข', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isAnalyzing) {
      return Scaffold(
        appBar: const CleanAppBar(title: 'ผลการวิเคราะห์อาหาร'),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: kGreen),
              SizedBox(height: 20),
              Text(
                'กำลังวิเคราะห์ภาพอาหาร...',
                style: TextStyle(color: kInk, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              SizedBox(height: 6),
              Text(
                'โมเดล AI กำลังประมวลผลเมนูและพลังงานจากภาพของคุณ',
                style: TextStyle(color: kMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final currentDailyCalories = context.content.totalDailyCalories;
    final dailyCalorieGoal = context.content.dailyGoal;

    final currentFood = _aiPredictions[_selectedMenuIndex];
    final double finalCalories = (currentFood['calories'] as double) * _portionMultiplier;

    final int weight = ((currentFood['weightGrams'] as int) * _portionMultiplier).round();
    final double depthCm = currentFood['depthCm'] as double;

    final double projectedTotal = currentDailyCalories + finalCalories;
    final double diffFromGoal = dailyCalorieGoal - projectedTotal;
    final bool isOverLimit = projectedTotal > dailyCalorieGoal;
    final bool isGoalReached = !isOverLimit && dailyCalorieGoal > 0 && diffFromGoal.abs() < 1;
    final double progressRatio = dailyCalorieGoal > 0 ? (projectedTotal / dailyCalorieGoal).clamp(0.0, 1.0) : 0.0;

    final String formattedTime =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')} น.';

    return Scaffold(
      appBar: const CleanAppBar(title: 'ผลการวิเคราะห์อาหาร'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border.all(color: kBorder, width: 1.5),
                  ),
                  child: _imageBytes != null
                      ? Image.memory(_imageBytes!, fit: BoxFit.cover, width: double.infinity, height: 200)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.restaurant_menu, size: 52, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text('ภาพถ่ายอาหารที่สแกน', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          ],
                        ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, size: 14, color: kGreen),
                      const SizedBox(width: 6),
                      Text(
                        'ความแม่นยำ ${currentFood['confidence']}%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kGreen),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kInk.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.layers_outlined, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        'ความลึก ${depthCm.toStringAsFixed(1)} ซม. • ปริมาณ ~$weight กรัม',
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ชื่อเมนู + ปุ่มระบุเอง
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  currentFood['name'] as String,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kInk),
                ),
              ),
              TextButton.icon(
                onPressed: _showCustomFoodDialog,
                icon: const Icon(Icons.edit_note, size: 18, color: kGreen),
                label: const Text('ระบุเอง', style: TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ChoiceChip เปอร์เซ็นต์ความเป็นไปได้ของเมนู
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
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? kGreenDark : kMuted,
                    ),
                    side: BorderSide(color: isSelected ? kGreen : kBorder),
                    onSelected: (_) => setState(() => _selectedMenuIndex = index),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),

          // พลังงานรวม + ปริมาณ + เวลาที่รับประทาน
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kGreenBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kGreen.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('พลังงานรวม', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kInk)),
                    Text(
                      '${finalCalories.toStringAsFixed(0)} kcal',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kGreen),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text('ปรับปริมาณ:', style: TextStyle(fontSize: 12, color: kMuted, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          _portionBtn('น้อย (0.5x)', 0.5),
                          const SizedBox(width: 6),
                          _portionBtn('ปกติ (1x)', 1.0),
                          const SizedBox(width: 6),
                          _portionBtn('พิเศษ (1.5x)', 1.5),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // ปุ่มเลือกเวลาที่รับประทาน
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('เวลาที่รับประทาน:', style: TextStyle(fontSize: 12, color: kMuted, fontWeight: FontWeight.w600)),
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(context: context, initialTime: _selectedTime);
                        if (picked != null) {
                          setState(() => _selectedTime = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kGreen.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time, size: 14, color: kGreen),
                            const SizedBox(width: 6),
                            Text(formattedTime, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kInk)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // เปรียบเทียบกับเป้าหมายรายวัน
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isOverLimit
                  ? kRedBg
                  : isGoalReached
                      ? kGreenBg
                      : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isOverLimit
                    ? kRed.withValues(alpha: 0.5)
                    : isGoalReached
                        ? kGreen
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
                      isOverLimit
                          ? Icons.warning_amber_rounded
                          : isGoalReached
                              ? Icons.check_circle
                              : Icons.track_changes,
                      color: isOverLimit ? kRed : (isGoalReached ? kGreenDark : kGreen),
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
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isOverLimit ? kRed : (isGoalReached ? kGreenDark : kInk),
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
                        : isGoalReached
                            ? Colors.white
                            : kGreenBg,
                    color: isOverLimit ? kRed : (isGoalReached ? kGreenDark : kGreen),
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
                        fontWeight: FontWeight.w600,
                        color: isOverLimit ? kRed : (isGoalReached ? kGreenDark : kMuted),
                      ),
                    ),
                    Text(
                      isOverLimit
                          ? 'เกิน ${diffFromGoal.abs().toStringAsFixed(0)} kcal'
                          : isGoalReached
                              ? 'ถึงเป้าหมายพอดี!'
                              : 'ขาดอีก ${diffFromGoal.toStringAsFixed(0)} kcal ถึงเป้า',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isOverLimit ? kRed : (isGoalReached ? kGreenDark : kGreen),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          PrimaryButton(
            'บันทึกลงในไดอารี่',
            () {
              context.content.logMeal(
                name: currentFood['name'] as String,
                calories: finalCalories,
                customTime: _selectedTime,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('บันทึกมื้ออาหารลงในไดอารี่เรียบร้อยแล้ว'),
                  backgroundColor: kGreen,
                ),
              );
              Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
            },
          ),
        ],
      ),
    );
  }

  Widget _portionBtn(String label, double value) {
    final isSelected = _portionMultiplier == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _portionMultiplier = value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? kGreen : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? kGreen : kGreen.withValues(alpha: 0.3)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : kInk,
            ),
          ),
        ),
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
    DateTime tempBirthDate = c.birthDate ?? DateTime(2001, 12, 12);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('แก้ไขข้อมูลบัญชี', style: TextStyle(fontWeight: FontWeight.bold, color: kInk)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ชื่อ - นามสกุล', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kMuted)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'กรอกชื่อ - นามสกุล',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('อีเมล', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kMuted)),
                const SizedBox(height: 6),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'กรอกอีเมล',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('วันเกิด', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kMuted)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: tempBirthDate,
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => tempBirthDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${tempBirthDate.day}/${tempBirthDate.month}/${tempBirthDate.year}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kInk),
                        ),
                        const Icon(Icons.calendar_today, size: 16, color: kGreen),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final newName = nameCtrl.text.trim();
                final newEmail = emailCtrl.text.trim();
                if (newName.isEmpty || newEmail.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบถ้วน'), backgroundColor: kRed),
                  );
                  return;
                }
                if (!RegExp(r'^[\w\.\+\-]+@[\w\-]+\.[\w\.\-]+$').hasMatch(newEmail)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('รูปแบบอีเมลไม่ถูกต้อง เช่น name@example.com'), backgroundColor: kRed),
                  );
                  return;
                }
                c.updateAccountInfo(
                  name: newName,
                  newEmail: newEmail,
                  newBirthDate: tempBirthDate,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('บันทึกข้อมูลบัญชีเรียบร้อยแล้ว'), backgroundColor: kGreen),
                );
              },
              child: const Text('บันทึก', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.content;
    final bDate = c.birthDate;
    final bDateStr = bDate == null ? '--' : '${bDate.day}/${bDate.month}/${bDate.year}';

    return BaseNavLayout(
      currentIndex: 2,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Center(child: Text('โปรไฟล์ส่วนตัว', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
          const SizedBox(height: 32),
          const Center(child: CircleAvatar(radius: 40, backgroundColor: Colors.black, child: Icon(Icons.person, color: Colors.white, size: 40))),
          const SizedBox(height: 32),

          _InfoCard(
            title: 'ข้อมูลบัญชี',
            trailingAction: InkWell(
              onTap: () => _showEditAccountDialog(context),
              child: const Text('แก้ไข', style: TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            items: {
              'ชื่อ - นามสกุล': c.fullName,
              'อีเมล': c.email,
              'วันเกิด': bDateStr,
            },
          ),
          const SizedBox(height: 16),

          InkWell(
            onTap: () => Navigator.pushNamed(context, '/change_password'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder),
              ),
              child: const Center(child: Text('เปลี่ยนรหัสผ่าน', style: TextStyle(fontWeight: FontWeight.bold))),
            ),
          ),
          const SizedBox(height: 16),

          _InfoCard(
            title: 'ข้อมูลสุขภาพและเป้าหมาย',
            trailingAction: InkWell(
              onTap: () => Navigator.pushNamed(context, '/health'),
              child: const Text('แก้ไข', style: TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            items: {
              'เพศ': c.gender,
              'น้ำหนัก': c.weightKg > 0 ? '${c.weightKg.toStringAsFixed(1)} กิโลกรัม' : '--',
              'ส่วนสูง': c.heightCm > 0 ? '${c.heightCm.toStringAsFixed(0)} เซนติเมตร' : '--',
              'อายุ': c.birthDate == null ? '--' : '${c.age} ปี',
              'เป้าหมายสุขภาพ': c.goalType,
              'ระดับกิจกรรม': c.activityLevel,
            },
          ),
          const SizedBox(height: 32),

          PrimaryButton(
            'ออกจากระบบ',
            () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('ออกจากระบบ', style: TextStyle(fontWeight: FontWeight.bold)),
                  content: const Text('คุณแน่ใจหรือไม่ว่าต้องการออกจากระบบ?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('ยกเลิก', style: TextStyle(color: kMuted)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: kRed),
                      onPressed: () {
                        context.auth.logout();
                        Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
                      },
                      child: const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
            color: kRedBg,
            textColor: kRed,
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final StringMap items;
  final Widget? trailingAction;
  const _InfoCard({required this.title, required this.items, this.trailingAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: kBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (trailingAction != null) trailingAction!,
            ],
          ),
          const SizedBox(height: 16),
          ...items.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: const TextStyle(color: kMuted, fontSize: 13)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        e.value,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CleanAppBar(title: 'เปลี่ยนรหัสผ่าน', showBack: true),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('รหัสผ่านเดิม', style: TextStyle(fontWeight: FontWeight.bold, color: kInk)),
            const SizedBox(height: 8),
            const CleanTextField(hint: 'กรอกรหัสผ่านเดิม', obscure: true),
            const SizedBox(height: 16),
            const Text('รหัสผ่านใหม่', style: TextStyle(fontWeight: FontWeight.bold, color: kInk)),
            const SizedBox(height: 8),
            const CleanTextField(hint: 'กรอกรหัสผ่านใหม่', obscure: true),
            const SizedBox(height: 16),
            const Text('ยืนยันรหัสผ่านใหม่', style: TextStyle(fontWeight: FontWeight.bold, color: kInk)),
            const SizedBox(height: 8),
            const CleanTextField(hint: 'กรอกรหัสผ่านใหม่อีกครั้ง', obscure: true),
            const Spacer(),
            PrimaryButton('บันทึกรหัสผ่านใหม่', () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('บันทึกรหัสผ่านใหม่สำเร็จแล้ว!'), backgroundColor: kGreen),
              );
              Navigator.pop(context);
            }),
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
              trailing: Switch(value: true, onChanged: (v) {}, activeTrackColor: kGreen),
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('แผงควบคุมผู้ดูแลระบบ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kInk)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: kRed),
            onPressed: () {
              context.auth.logout();
              Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _AdminMenuCard(
              title: 'จัดการบัญชีผู้ใช้ (${context.content.users.length})',
              icon: Icons.people,
              onTap: () => Navigator.pushNamed(context, '/admin/users'),
            ),
            const SizedBox(height: 16),
            _AdminMenuCard(
              title: 'จัดการโภชนาการอาหาร (${context.content.adminFoods.length})',
              icon: Icons.fastfood,
              onTap: () => Navigator.pushNamed(context, '/admin/foods'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminMenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _AdminMenuCard({required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder, width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: kGreenBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: kGreen),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            const Icon(Icons.chevron_right, color: kMuted),
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
          const Center(child: CircleAvatar(radius: 40, backgroundColor: Colors.black, child: Icon(Icons.person, color: Colors.white, size: 40))),
          const SizedBox(height: 16),
          const Center(child: Text('ผู้ดูแลระบบ', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
          const SizedBox(height: 24),
          CleanTextField(
            hint: 'ค้นหารหัสผู้ใช้ หรือ ชื่อผู้ใช้',
            icon: Icons.search,
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          ...filtered.map((entry) => _UserCard(id: entry.key, userData: entry.value)),
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: kBorder)),
      child: Column(
        children: [
          Row(
            children: [
              Text('รหัสผู้ใช้ : $id', style: const TextStyle(fontWeight: FontWeight.bold, color: kMuted)),
              const Spacer(),
              Row(children: [
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.pushNamed(context, '/admin/users/edit', arguments: id),
                  child: _outlineBtn('แก้ไข', kGreen, Icons.edit),
                ),
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('ยืนยันการลบผู้ใช้'),
                        content: Text('ต้องการลบบัญชีของ "${userData['name']}" ใช่หรือไม่?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก', style: TextStyle(color: kMuted))),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: kRed),
                            onPressed: () {
                              context.content.deleteUser(id);
                              Navigator.pop(ctx);
                            },
                            child: const Text('ลบ', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: _outlineBtn('ลบ', kRed, Icons.delete_outline),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ชื่อผู้ใช้ :', style: TextStyle(color: kMuted)),
              Flexible(child: Text(userData['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('อีเมล :', style: TextStyle(color: kMuted)),
              Flexible(child: Text(userData['email'] ?? '', style: const TextStyle(color: kBlue))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _outlineBtn(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: color)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ───────────────────────── 12. Admin Foods ─────────────────────────
class AdminFoodsScreen extends StatelessWidget {
  const AdminFoodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final foodList = context.content.adminFoods;

    return Scaffold(
      appBar: const CleanAppBar(title: 'จัดการโภชนาการอาหาร'),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          PrimaryButton('เพิ่มข้อมูลโภชนาการอาหาร', () => Navigator.pushNamed(context, '/admin/foods/add')),
          const SizedBox(height: 24),
          Text('รายการอาหารในระบบ (${foodList.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  Icon(Icons.restaurant_menu, size: 40, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  const Text(
                    'ยังไม่มีข้อมูลอาหารในระบบ',
                    style: TextStyle(fontWeight: FontWeight.bold, color: kInk, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'กดปุ่ม "เพิ่มข้อมูลโภชนาการอาหาร" ด้านบนเพื่อเริ่มเพิ่มเมนูแรกของคุณ',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kMuted, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ...List.generate(foodList.length, (index) {
            final item = foodList[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder, width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: kGreenBg, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.restaurant_menu, color: kGreen),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: kInk)),
                        if (item['engName'] != null && item['engName']!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(item['engName']!, style: const TextStyle(fontSize: 12, color: kMuted, fontStyle: FontStyle.italic)),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          'พลังงาน ${item['energy']} kcal',
                          style: const TextStyle(fontSize: 13, color: kGreenDark, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  // ปุ่มลบ
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: kRed),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('ยืนยันการลบ'),
                          content: Text('ต้องการลบเมนู "${item['name']}" หรือไม่?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก', style: TextStyle(color: kMuted))),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: kRed),
                              onPressed: () {
                                context.content.deleteFoodAt(index);
                                Navigator.pop(ctx);
                              },
                              child: const Text('ลบ', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    },
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

// ───────────────────────── 13. Admin Add Food ─────────────────────────
class AdminAddFoodScreen extends StatefulWidget {
  const AdminAddFoodScreen({super.key});
  @override
  State<AdminAddFoodScreen> createState() => _AdminAddFoodScreenState();
}

class _AdminAddFoodScreenState extends State<AdminAddFoodScreen> {
  final _name = TextEditingController();
  final _engName = TextEditingController();
  final _energy = TextEditingController();

  String? _nameError;
  String? _engNameError;
  String? _energyError;

  @override
  void dispose() {
    _name.dispose();
    _engName.dispose();
    _energy.dispose();
    super.dispose();
  }

  bool _validate() {
    final name = _name.text.trim();
    final engName = _engName.text.trim();
    final energyText = _energy.text.trim();
    final parsedEnergy = double.tryParse(energyText);

    setState(() {
      _nameError = name.isEmpty ? 'กรุณากรอกชื่ออาหาร (ภาษาไทย)' : null;
      _engNameError = engName.isEmpty ? 'กรุณากรอกชื่ออาหาร (ภาษาอังกฤษ)' : null;
      _energyError = energyText.isEmpty
          ? 'กรุณากรอกพลังงาน'
          : (parsedEnergy == null
              ? 'พลังงานต้องเป็นตัวเลขเท่านั้น'
              : (parsedEnergy <= 0 ? 'พลังงานต้องมากกว่า 0' : null));
    });

    return _nameError == null && _engNameError == null && _energyError == null;
  }

  void _save() {
    if (!_validate()) return;

    final name = _name.text.trim();
    final engName = _engName.text.trim();
    final energy = _energy.text.trim();

    context.content.addFood({
      'name': name,
      'engName': engName,
      'energy': energy,
      'source': 'admin',
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('เพิ่มข้อมูลโภชนาการอาหารสำเร็จ'), backgroundColor: kGreen),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'เพิ่มโภชนาการอาหาร',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kInk),
                      ),
                      const SizedBox(height: 4),
                      const Text('เพิ่มข้อมูลเมนูอาหารใหม่เข้าสู่ระบบ', style: TextStyle(color: kMuted, fontSize: 13)),
                      const SizedBox(height: 28),
                      _FoodField(label: 'ชื่ออาหาร (ภาษาไทย)', hint: 'เช่น ข้าวมันไก่ต้ม', controller: _name, errorText: _nameError),
                      _FoodField(label: 'ชื่ออาหาร (ภาษาอังกฤษ)', hint: 'เช่น Khao_mun_gai', controller: _engName, errorText: _engNameError),
                      _FoodField(label: 'พลังงาน (กิโลแคลอรี)', hint: '0', controller: _energy, numeric: true, errorText: _energyError),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: kBorder, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('ยกเลิก', style: TextStyle(color: kInk, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(color: kGreen.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kGreen,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                          ),
                          onPressed: _save,
                          child: const Text('บันทึกข้อมูล', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 13.5 Admin Edit Food (แก้ไขเมนู) ─────────────────────────
class AdminEditFoodScreen extends StatefulWidget {
  const AdminEditFoodScreen({super.key});
  @override
  State<AdminEditFoodScreen> createState() => _AdminEditFoodScreenState();
}

class _AdminEditFoodScreenState extends State<AdminEditFoodScreen> {
  final _name = TextEditingController();
  final _engName = TextEditingController();
  final _energy = TextEditingController();

  String? _nameError;
  String? _engNameError;
  String? _energyError;
  
  int _foodIndex = -1;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final idx = ModalRoute.of(context)?.settings.arguments as int?;
      if (idx != null) {
        _foodIndex = idx;
        final foodData = context.content.adminFoods[_foodIndex];
        _name.text = foodData['name'] ?? '';
        _engName.text = foodData['engName'] ?? '';
        _energy.text = foodData['energy'] ?? '';
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _engName.dispose();
    _energy.dispose();
    super.dispose();
  }

  bool _validate() {
    final name = _name.text.trim();
    final engName = _engName.text.trim();
    final energyText = _energy.text.trim();
    final parsedEnergy = double.tryParse(energyText);

    setState(() {
      _nameError = name.isEmpty ? 'กรุณากรอกชื่ออาหาร (ภาษาไทย)' : null;
      _engNameError = engName.isEmpty ? 'กรุณากรอกชื่ออาหาร (ภาษาอังกฤษ)' : null;
      _energyError = energyText.isEmpty
          ? 'กรุณากรอกพลังงาน'
          : (parsedEnergy == null
              ? 'พลังงานต้องเป็นตัวเลขเท่านั้น'
              : (parsedEnergy <= 0 ? 'พลังงานต้องมากกว่า 0' : null));
    });

    return _nameError == null && _engNameError == null && _energyError == null;
  }

  void _save() {
    if (!_validate() || _foodIndex < 0) return;

    final name = _name.text.trim();
    final engName = _engName.text.trim();
    final energy = _energy.text.trim();

    context.content.updateFoodAt(_foodIndex, {
      'name': name,
      'engName': engName,
      'energy': energy,
      'source': 'admin',
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('แก้ไขข้อมูลโภชนาการอาหารสำเร็จ'), backgroundColor: kGreen),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'แก้ไขข้อมูลอาหาร',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kInk),
                      ),
                      const SizedBox(height: 28),
                      _FoodField(label: 'ชื่ออาหาร (ภาษาไทย)', hint: 'เช่น ข้าวมันไก่ต้ม', controller: _name, errorText: _nameError),
                      _FoodField(label: 'ชื่ออาหาร (ภาษาอังกฤษ)', hint: 'เช่น Khao_mun_gai', controller: _engName, errorText: _engNameError),
                      _FoodField(label: 'พลังงาน (กิโลแคลอรี)', hint: '0', controller: _energy, numeric: true, errorText: _energyError),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: kBorder, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('ยกเลิก', style: TextStyle(color: kInk, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(color: kGreen.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kGreen,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                          ),
                          onPressed: _save,
                          child: const Text('บันทึกการแก้ไข', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
  const _FoodField({
    required this.label,
    required this.hint,
    required this.controller,
    this.numeric = false,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: kInk)),
          const SizedBox(height: 8),
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: hasError ? kRed : kBorder, width: 1.5),
              boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: TextField(
              controller: controller,
              keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
              inputFormatters: numeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
              style: const TextStyle(fontSize: 14, color: kInk),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
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
                Expanded(child: Text(errorText!, style: const TextStyle(color: kRed, fontSize: 12, fontWeight: FontWeight.w600))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────── Date of Birth (ภาษาไทยล้วน) ─────────────────────────
class DobScreen extends StatefulWidget {
  const DobScreen({super.key});
  @override
  State<DobScreen> createState() => _DobScreenState();
}

class _DobScreenState extends State<DobScreen> {
  static const _months = [
    'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
    'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
  ];
  static const int _minYear = 1900;
  final int _maxYear = DateTime.now().year;

  int _day = 1;
  int _month = 1;
  int _year = 2000;
  bool _initialized = false;

  late final FixedExtentScrollController _dayCtrl;
  late final FixedExtentScrollController _monthCtrl;
  late final FixedExtentScrollController _yearCtrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final saved = context.content.birthDate;
      if (saved != null) {
        _day = saved.day;
        _month = saved.month;
        _year = saved.year;
      }
      _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
      _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
      _yearCtrl = FixedExtentScrollController(initialItem: _year - _minYear);
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    _monthCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  int _daysIn(int year, int month) => DateTime(year, month + 1, 0).day;

  void _clampDay() {
    final max = _daysIn(_year, _month);
    if (_day > max) {
      _day = max;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_dayCtrl.hasClients) _dayCtrl.jumpToItem(_day - 1);
      });
    }
  }

  void _next() {
    final date = DateTime(_year, _month, _day);
    final now = DateTime.now();
    if (date.isAfter(DateTime(now.year, now.month, now.day))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('วันเกิดต้องไม่เป็นวันที่ในอนาคต'), backgroundColor: kRed),
      );
      return;
    }
    context.content.updateAccountInfo(newBirthDate: date);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('วันเกิดของคุณ', style: TextStyle(fontWeight: FontWeight.bold, color: kInk)),
        content: Text(
          '$_day ${_months[_month - 1]} $_year',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kGreenDark),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/health');
            },
            child: const Text('ตกลง', style: TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final itemExtent = (c.maxHeight * 0.075).clamp(40.0, 56.0);
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'คุณเกิดวันที่เท่าไหร่?',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'ข้อมูลนี้จะถูกนำไปใช้ปรับแต่งแผนโภชนาการให้เหมาะกับวัยของคุณ',
                          style: TextStyle(fontSize: 13, color: kMuted),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 8, bottom: 14),
                                child: Text(
                                  'วัน / เดือน / ปีเกิด',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kInk),
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: _Wheel(
                                      label: 'วันที่',
                                      count: _daysIn(_year, _month),
                                      selected: _day - 1,
                                      controller: _dayCtrl,
                                      itemExtent: itemExtent,
                                      textOf: (i) => '${i + 1}',
                                      onChanged: (i) => setState(() => _day = i + 1),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: _Wheel(
                                      label: 'เดือน',
                                      count: 12,
                                      selected: _month - 1,
                                      controller: _monthCtrl,
                                      itemExtent: itemExtent,
                                      fontSize: 14,
                                      textOf: (i) => _months[i],
                                      onChanged: (i) => setState(() {
                                        _month = i + 1;
                                        _clampDay();
                                      }),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _Wheel(
                                      label: 'ปี (ค.ศ.)',
                                      count: _maxYear - _minYear + 1,
                                      selected: _year - _minYear,
                                      controller: _yearCtrl,
                                      itemExtent: itemExtent,
                                      textOf: (i) => '${_minYear + i}',
                                      onChanged: (i) => setState(() {
                                        _year = _minYear + i;
                                        _clampDay();
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(color: kGreen.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                      onPressed: _next,
                      child: const Text(
                        'ถัดไป',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  final String label;
  final int count;
  final int selected;
  final FixedExtentScrollController controller;
  final double itemExtent;
  final double fontSize;
  final String Function(int) textOf;
  final ValueChanged<int> onChanged;

  const _Wheel({
    required this.label,
    required this.count,
    required this.selected,
    required this.controller,
    required this.itemExtent,
    required this.textOf,
    required this.onChanged,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kMuted)),
        const SizedBox(height: 8),
        SizedBox(
          height: itemExtent * 5,
          child: ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: itemExtent,
            physics: const FixedExtentScrollPhysics(),
            diameterRatio: 100,
            perspective: 0.0001,
            onSelectedItemChanged: onChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: count,
              builder: (context, i) {
                final sel = i == selected;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel ? kGreenBg : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: sel ? kGreen.withValues(alpha: 0.4) : const Color(0xFFE5E7EB), width: 1),
                    ),
                    child: Text(
                      textOf(i),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                        color: sel ? kGreenDark : kInk,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
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
  final TextEditingController _password = TextEditingController();
  final TextEditingController _resetPassword = TextEditingController();
  String _id = '';
  String _role = 'ผู้ใช้งาน';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_name == null) {
      _id = (ModalRoute.of(context)?.settings.arguments as String?) ?? '';
      final userData = context.content.users[_id] ?? {};
      _name = TextEditingController(text: userData['name'] ?? '');
      _email = TextEditingController(text: userData['email'] ?? '');
      final rawRole = userData['role'] ?? 'ผู้ใช้งาน';
      _role = (rawRole == 'Admin' || rawRole == 'ผู้ดูแลระบบ') ? 'ผู้ดูแลระบบ' : 'ผู้ใช้งาน';
      _password.text = '12345678';
    }
  }

  @override
  void dispose() {
    _name?.dispose();
    _email?.dispose();
    _password.dispose();
    _resetPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CleanAppBar(title: 'จัดการบัญชีผู้ใช้'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      const CircleAvatar(radius: 40, backgroundColor: kBorder, child: Icon(Icons.person, color: kInk, size: 40)),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, size: 16, color: kMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('เปลี่ยนรูปโปรไฟล์', style: TextStyle(color: kGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 32),

            const Text('ชื่อ - นามสกุล', style: TextStyle(fontWeight: FontWeight.bold, color: kMuted, fontSize: 12)),
            const SizedBox(height: 8),
            CleanTextField(hint: 'ชื่อ นามสกุล', controller: _name, suffixIcon: Icons.edit_square),

            const Text('อีเมล', style: TextStyle(fontWeight: FontWeight.bold, color: kMuted, fontSize: 12)),
            const SizedBox(height: 8),
            CleanTextField(hint: 'อีเมล', controller: _email, suffixIcon: Icons.edit_square),

            const Text('บทบาท (สิทธิ์การใช้งาน)', style: TextStyle(fontWeight: FontWeight.bold, color: kMuted, fontSize: 12)),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder, width: 1.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _role,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down, color: kMuted),
                  items: ['ผู้ใช้งาน', 'ผู้ดูแลระบบ'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: const TextStyle(fontSize: 14, color: kInk)),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _role = newValue!;
                    });
                  },
                ),
              ),
            ),

            const Text('รหัสผ่าน', style: TextStyle(fontWeight: FontWeight.bold, color: kMuted, fontSize: 12)),
            const SizedBox(height: 8),
            CleanTextField(hint: 'รหัสผ่าน', controller: _password, obscure: true),

            const Text('รีเซ็ตรหัสผ่าน', style: TextStyle(fontWeight: FontWeight.bold, color: kMuted, fontSize: 12)),
            const SizedBox(height: 8),
            CleanTextField(hint: 'กรอกรหัสผ่านใหม่ที่ต้องการรีเซ็ต', controller: _resetPassword),

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: kBorder, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ยกเลิก', style: TextStyle(color: kMuted, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: () {
                      context.content.updateUser(_id, {
                        'name': _name!.text.trim(),
                        'email': _email!.text.trim(),
                        'role': _role,
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('บันทึกข้อมูลผู้ใช้สำเร็จ'), backgroundColor: kGreen),
                      );
                      Navigator.pop(context);
                    },
                    child: const Text('บันทึกข้อมูล', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}