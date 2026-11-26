import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import 'dashboard_screen.dart';
import 'month_screen.dart';
import 'profile_screen.dart';
import 'scan_screen.dart';

/// หน้าหลักหลังเข้าสู่ระบบ: แถบเมนูด้านล่าง 4 แท็บ
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  void _go(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(onScan: () => _go(1), onOpenMonth: () => _go(2)),
      ScanScreen(onSaved: () => _go(0)),
      const MonthScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: IndexedStack(index: _tab, children: pages),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _go,
        backgroundColor: Colors.white,
        indicatorColor: kGreenBg,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: kGreenDark),
            label: 'หน้าหลัก',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_camera_outlined),
            selectedIcon: Icon(Icons.photo_camera_rounded, color: kGreenDark),
            label: 'สแกน',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded, color: kGreenDark),
            label: 'สรุปเดือน',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded, color: kGreenDark),
            label: 'โปรไฟล์',
          ),
        ],
      ),
    );
  }
}
