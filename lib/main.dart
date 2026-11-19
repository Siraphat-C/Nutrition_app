import 'package:material_ui/material_ui.dart';

import 'screens/admin_screens.dart';
import 'screens/auth_screens.dart';
import 'screens/home_shell.dart';
import 'screens/setup_screen.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppState.instance.restore();
  runApp(const NutritionApp());
}

class NutritionApp extends StatelessWidget {
  const NutritionApp({super.key});

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
    final app = AppState.instance;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        if (!app.isLoggedIn) return const LoginScreen();
        if (app.isAdmin) return const AdminShell();
        if (!app.profileComplete) return const SetupScreen();
        return const HomeShell();
      },
    );
  }
}
