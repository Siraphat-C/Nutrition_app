import 'package:material_ui/material_ui.dart';

import '../data/foods.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'auth_screens.dart';

/// หน้าแอดมิน (role_id = 1): ภาพรวม / ผู้ใช้ / เมนูอาหาร
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _tab = 0;

  Future<void> _logout() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ออกจากระบบ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('ออกจากระบบ')),
        ],
      ),
    );
    if (yes == true) await AppState.instance.logout();
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['ภาพรวม', 'จัดการผู้ใช้', 'จัดการเมนูอาหาร'];
    return Scaffold(
      appBar: AppBar(
        title: Text('แอดมิน · ${titles[_tab]}'),
        actions: [
          IconButton(tooltip: 'ออกจากระบบ', onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: IndexedStack(
              index: _tab,
              children: [
                _Overview(onOpen: (i) => setState(() => _tab = i)),
                const _UsersTab(),
                const _FoodsTab(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: Colors.white,
        indicatorColor: kGreenBg,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard_rounded, color: kGreenDark),
            label: 'ภาพรวม',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group_rounded, color: kGreenDark),
            label: 'ผู้ใช้',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu_rounded, color: kGreenDark),
            label: 'เมนูอาหาร',
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── ภาพรวม ─────────────────────────

class _Overview extends StatefulWidget {
  final ValueChanged<int> onOpen;
  const _Overview({required this.onOpen});

  @override
  State<_Overview> createState() => _OverviewState();
}

class _OverviewState extends State<_Overview> {
  Map<String, dynamic>? _stats;
  int _missingCalories = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = AppState.instance.api;
      final data = await api.adminDashboard();
      final foods = await api.foods();
      if (!mounted) return;
      setState(() {
        _stats = Map<String, dynamic>.from(data['stats'] ?? {});
        _missingCalories = foods.where((f) => (toDouble(f['calories_per_100g']) ?? 0) <= 0).length;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    return RefreshIndicator(
      color: kGreenDark,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('สวัสดี, ${AppState.instance.username}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kInk)),
          const SizedBox(height: 14),
          if (_error != null)
            AlertCard(level: AlertLevel.danger, title: 'โหลดข้อมูลไม่ได้', detail: _error!)
          else if (s == null)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: kGreenDark)),
            )
          else ...[
            Row(
              children: [
                Expanded(child: _StatCard(label: 'ผู้ใช้ทั้งหมด', value: '${s['total_users'] ?? 0}', icon: Icons.group_outlined, onTap: () => widget.onOpen(1))),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(label: 'แอดมิน', value: '${s['total_admins'] ?? 0}', icon: Icons.admin_panel_settings_outlined, onTap: () => widget.onOpen(1))),
              ],
            ),
            const SizedBox(height: 12),
            _StatCard(label: 'เมนูอาหาร', value: '${s['total_foods'] ?? 0}', icon: Icons.restaurant_menu_outlined, onTap: () => widget.onOpen(2)),
            if (_missingCalories > 0) ...[
              const SizedBox(height: 12),
              AlertCard(
                level: AlertLevel.warning,
                title: 'มี $_missingCalories เมนูที่ยังไม่มีแคลอรี่',
                detail: 'ผู้ใช้ที่สแกนเมนูเหล่านี้จะเห็น "ยังไม่มีข้อมูล" แตะแท็บเมนูอาหารเพื่อเติมค่า',
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  const _StatCard({required this.label, required this.value, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: kGreenBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: kGreenDark),
              ),
              const SizedBox(width: 12),
              Expanded(child: StatTile(label: label, value: value)),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── ผู้ใช้ ─────────────────────────

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _search = TextEditingController();
  List<Map<String, dynamic>>? _users;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      // backend รับคำค้นที่ไม่มีเว้นวรรค
      final q = _search.text.trim().replaceAll(RegExp(r'\s+'), '');
      final users = await AppState.instance.api.adminUsers(q: q);
      if (mounted) {
        setState(() {
          _users = users;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _openForm([Map<String, dynamic>? user]) async {
    final changed = await showDialog<bool>(context: context, builder: (_) => _UserForm(user: user));
    if (changed == true) await _load();
  }

  Future<void> _delete(Map<String, dynamic> user) async {
    final yes = await _confirm(context, 'ลบบัญชี ${user['username']}?',
        'ข้อมูลส่วนตัว มื้ออาหาร และน้ำหนักของผู้ใช้นี้จะถูกลบทั้งหมด ย้อนกลับไม่ได้');
    if (!yes) return;
    try {
      await AppState.instance.api.adminDeleteUser((user['user_id'] as num).toInt());
      if (mounted) showSnack(context, 'ลบบัญชีแล้ว');
      await _load();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = (AppState.instance.user?['user_id'] as num?)?.toInt();
    return Stack(
      children: [
        RefreshIndicator(
          color: kGreenDark,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  hintText: 'ค้นหาชื่อผู้ใช้หรืออีเมล',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(tooltip: 'ค้นหา', onPressed: _load, icon: const Icon(Icons.arrow_forward)),
                ),
              ),
              const SizedBox(height: 14),
              if (_error != null)
                AlertCard(level: AlertLevel.danger, title: 'โหลดรายชื่อไม่ได้', detail: _error!)
              else if (_users == null)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: kGreenDark)))
              else if (_users!.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Text('ไม่พบผู้ใช้', textAlign: TextAlign.center, style: TextStyle(color: kMuted)),
                )
              else
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (var i = 0; i < _users!.length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        _userTile(_users![i], me),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            backgroundColor: kGreen,
            foregroundColor: Colors.white,
            onPressed: () => _openForm(),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('เพิ่มผู้ใช้'),
          ),
        ),
      ],
    );
  }

  Widget _userTile(Map<String, dynamic> u, int? me) {
    final isAdmin = (u['role_id'] as num?)?.toInt() == 1;
    final isMe = (u['user_id'] as num?)?.toInt() == me;
    return ListTile(
      onTap: () => _openForm(u),
      leading: CircleAvatar(
        backgroundColor: isAdmin ? const Color(0xFFEDE7FE) : kGreenBg,
        child: Icon(isAdmin ? Icons.admin_panel_settings_outlined : Icons.person_outline,
            color: isAdmin ? kPurple : kGreenDark),
      ),
      title: Text('${u['username']}${isMe ? ' (คุณ)' : ''}',
          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${u['email']} · ${isAdmin ? 'แอดมิน' : 'ผู้ใช้'}', maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: isMe
          ? null
          : IconButton(
              tooltip: 'ลบบัญชี',
              onPressed: () => _delete(u),
              icon: const Icon(Icons.delete_outline, color: kRedText),
            ),
    );
  }
}

class _UserForm extends StatefulWidget {
  final Map<String, dynamic>? user;
  const _UserForm({this.user});

  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  final _form = GlobalKey<FormState>();
  late final _username = TextEditingController(text: '${widget.user?['username'] ?? ''}');
  late final _email = TextEditingController(text: '${widget.user?['email'] ?? ''}');
  final _password = TextEditingController();
  late int _role = (widget.user?['role_id'] as num?)?.toInt() ?? 2;
  bool _busy = false;
  String? _error;

  bool get _editing => widget.user != null;
  bool get _isMe =>
      _editing && (widget.user!['user_id'] as num?)?.toInt() == (AppState.instance.user?['user_id'] as num?)?.toInt();

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = AppState.instance.api;
    try {
      if (_editing) {
        final u = widget.user!;
        final fields = <String, dynamic>{
          if (cleanUsername(_username.text) != u['username']) 'username': cleanUsername(_username.text),
          if (_email.text.trim().toLowerCase() != '${u['email']}'.toLowerCase()) 'email': _email.text.trim(),
          if (_role != (u['role_id'] as num?)?.toInt()) 'role_id': _role,
          if (_password.text.isNotEmpty) 'new_password': _password.text,
        };
        if (fields.isEmpty) {
          if (mounted) Navigator.pop(context, false);
          return;
        }
        await api.adminUpdateUser((u['user_id'] as num).toInt(), fields);
      } else {
        await api.adminCreateUser({
          'username': cleanUsername(_username.text),
          'email': _email.text.trim(),
          'password': _password.text,
          'role_id': _role,
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editing ? 'แก้ไขผู้ใช้' : 'เพิ่มผู้ใช้'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _username,
                  decoration: const InputDecoration(labelText: 'ชื่อผู้ใช้ (ไทย/อังกฤษ)'),
                  validator: validateUsername,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'อีเมล'),
                  validator: (v) =>
                      RegExp(r'^[\w.+\-]+@[\w\-]+\.[\w.\-]+$').hasMatch(v?.trim() ?? '') ? null : 'กรอกอีเมลให้ถูกต้อง',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: _editing ? 'รหัสผ่านใหม่ (เว้นว่าง = ไม่เปลี่ยน)' : 'รหัสผ่าน (อย่างน้อย 8 ตัว)',
                  ),
                  validator: (v) {
                    final s = v ?? '';
                    if (_editing && s.isEmpty) return null;
                    return s.length < 8 ? 'อย่างน้อย 8 ตัว' : null;
                  },
                ),
                const SizedBox(height: 14),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 2, label: Text('ผู้ใช้'), icon: Icon(Icons.person_outline)),
                    ButtonSegment(value: 1, label: Text('แอดมิน'), icon: Icon(Icons.admin_panel_settings_outlined)),
                  ],
                  selected: {_role},
                  onSelectionChanged: _isMe ? null : (v) => setState(() => _role = v.first),
                ),
                if (_isMe)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('เปลี่ยนสิทธิ์บัญชีตัวเองไม่ได้', style: TextStyle(fontSize: 12, color: kMuted)),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: kRedText, fontSize: 13)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
        FilledButton(onPressed: _busy ? null : _save, child: Text(_editing ? 'บันทึก' : 'เพิ่ม')),
      ],
    );
  }
}

// ───────────────────────── เมนูอาหาร ─────────────────────────

class _FoodsTab extends StatefulWidget {
  const _FoodsTab();

  @override
  State<_FoodsTab> createState() => _FoodsTabState();
}

class _FoodsTabState extends State<_FoodsTab> {
  List<Map<String, dynamic>>? _foods;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final foods = await AppState.instance.api.foods();
      foods.sort((a, b) => thaiFoodName(a['food_name'] as String?).compareTo(thaiFoodName(b['food_name'] as String?)));
      if (mounted) {
        setState(() {
          _foods = foods;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _openForm([Map<String, dynamic>? food]) async {
    final changed = await showDialog<bool>(context: context, builder: (_) => _FoodForm(food: food));
    if (changed == true) await _load();
  }

  Future<void> _delete(Map<String, dynamic> f) async {
    final yes = await _confirm(context, 'ลบเมนู ${thaiFoodName(f['food_name'] as String?)}?',
        'ถ้ามีผู้ใช้บันทึกเมนูนี้ไว้แล้วจะลบไม่ได้ ถ้าโมเดล AI ยังทายเมนูนี้ได้ ผู้ใช้จะเห็นว่าไม่มีในฐานข้อมูล');
    if (!yes) return;
    try {
      await AppState.instance.api.adminDeleteFood((f['food_id'] as num).toInt());
      if (mounted) showSnack(context, 'ลบเมนูแล้ว');
      await _load();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          color: kGreenDark,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              const Text('แคลอรี่คิดต่อ 100 กรัม แตะเมนูเพื่อแก้ไข',
                  style: TextStyle(fontSize: 13, color: kMuted)),
              const SizedBox(height: 10),
              if (_error != null)
                AlertCard(level: AlertLevel.danger, title: 'โหลดเมนูไม่ได้', detail: _error!)
              else if (_foods == null)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: kGreenDark)))
              else
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (var i = 0; i < _foods!.length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        _foodTile(_foods![i]),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            backgroundColor: kGreen,
            foregroundColor: Colors.white,
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add),
            label: const Text('เพิ่มเมนู'),
          ),
        ),
      ],
    );
  }

  Widget _foodTile(Map<String, dynamic> f) {
    final kcal = toDouble(f['calories_per_100g']) ?? 0;
    final missing = kcal <= 0;
    return ListTile(
      onTap: () => _openForm(f),
      title: Text(thaiFoodName(f['food_name'] as String?), style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${f['food_name']}', style: const TextStyle(fontSize: 12, color: kMuted)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          missing
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: kOrangeBg, borderRadius: BorderRadius.circular(99)),
                  child: const Text('ยังไม่มีข้อมูล',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kOrangeText)),
                )
              : Text('${fmtInt(kcal)} kcal', style: const TextStyle(fontWeight: FontWeight.w700, color: kInk)),
          IconButton(
            tooltip: 'ลบเมนู',
            onPressed: () => _delete(f),
            icon: const Icon(Icons.delete_outline, color: kRedText),
          ),
        ],
      ),
    );
  }
}

class _FoodForm extends StatefulWidget {
  final Map<String, dynamic>? food;
  const _FoodForm({this.food});

  @override
  State<_FoodForm> createState() => _FoodFormState();
}

class _FoodFormState extends State<_FoodForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: '${widget.food?['food_name'] ?? ''}');
  late final _kcal = TextEditingController(
      text: widget.food == null ? '' : '${toDouble(widget.food!['calories_per_100g']) ?? 0}');
  bool _busy = false;
  String? _error;

  bool get _editing => widget.food != null;

  @override
  void dispose() {
    _name.dispose();
    _kcal.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = AppState.instance.api;
    final name = _name.text.trim();
    final kcal = double.parse(_kcal.text.trim());
    try {
      if (_editing) {
        final f = widget.food!;
        final fields = <String, dynamic>{
          if (name != f['food_name']) 'food_name': name,
          if (kcal != toDouble(f['calories_per_100g'])) 'calories_per_100g': kcal,
        };
        if (fields.isEmpty) {
          if (mounted) Navigator.pop(context, false);
          return;
        }
        await api.adminUpdateFood((f['food_id'] as num).toInt(), fields);
      } else {
        await api.adminCreateFood(name, kcal);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editing ? 'แก้ไขเมนู' : 'เพิ่มเมนู'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'ชื่อเมนู (ชื่อคลาสของโมเดล)',
                  helperText: 'ต้องตรงกับชื่อที่โมเดล AI ทาย เช่น khao_man_kai',
                  helperMaxLines: 2,
                ),
                validator: (v) {
                  final s = v?.trim() ?? '';
                  if (s.isEmpty || s.length > 100) return 'ยาว 1–100 ตัวอักษร';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _kcal,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'แคลอรี่ต่อ 100 กรัม', suffixText: 'kcal'),
                validator: (v) {
                  final n = double.tryParse(v?.trim() ?? '');
                  if (n == null || n < 0 || n > 900) return 'ใส่ตัวเลข 0–900';
                  return null;
                },
              ),
              if (_editing && thaiFoodName(widget.food!['food_name'] as String?) != widget.food!['food_name']) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('ชื่อในแอป: ${thaiFoodName(widget.food!['food_name'] as String?)}',
                      style: const TextStyle(fontSize: 12, color: kMuted)),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: kRedText, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
        FilledButton(onPressed: _busy ? null : _save, child: Text(_editing ? 'บันทึก' : 'เพิ่ม')),
      ],
    );
  }
}

Future<bool> _confirm(BuildContext context, String title, String detail) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(detail),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ยกเลิก')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kRedText),
          onPressed: () => Navigator.pop(c, true),
          child: const Text('ลบ'),
        ),
      ],
    ),
  );
  return yes == true;
}
