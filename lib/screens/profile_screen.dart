import 'package:material_ui/material_ui.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'auth_screens.dart';
import 'setup_screen.dart';

const _activityNames = {
  1: 'นั่งเป็นหลัก',
  2: 'ยืนหรือเดินบ้าง',
  3: 'ยืนหรือเดินเกือบทั้งวัน',
  4: 'งานใช้แรง',
  5: 'งานใช้แรงหนัก',
};
const _goalNames = {'lose': 'ลดน้ำหนัก', 'maintain': 'รักษาน้ำหนัก', 'gain': 'เพิ่มน้ำหนัก'};

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final p = app.profile ?? {};
        final bmi = app.bmi;
        final cat = bmi == null ? null : bmiCategory(bmi);
        final birth = DateTime.tryParse('${p['birth_date']}');
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const Text('โปรไฟล์', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kInk)),
            const SizedBox(height: 14),
            AppCard(
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: kGreenBg, borderRadius: BorderRadius.circular(28)),
                    child: Text(
                      app.username.isEmpty ? '?' : app.username.substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kGreenText),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(app.username,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kInk)),
                        Text(app.email, style: const TextStyle(fontSize: 13, color: kMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'แก้ชื่อ',
                    onPressed: () => showDialog<void>(context: context, builder: (_) => const _EditNameDialog()),
                    icon: const Icon(Icons.edit_outlined, color: kGreenText),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(
                    'ร่างกายและเป้าหมาย',
                    trailing: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SetupScreen(editing: true)),
                      ),
                      child: const Text('แก้ไข', style: TextStyle(fontWeight: FontWeight.w700, color: kGreenText)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _Row('เพศ', p['gender'] == 'male' ? 'ชาย' : (p['gender'] == 'female' ? 'หญิง' : '-')),
                  _Row('วันเกิด', birth == null ? '-' : fmtThaiShortDate(birth)),
                  _Row('น้ำหนัก', p['weight'] == null ? '-' : '${p['weight']} กก.'),
                  _Row('ส่วนสูง', p['height'] == null ? '-' : '${p['height']} ซม.'),
                  _Row('BMI', bmi == null ? '-' : '${bmi.toStringAsFixed(1)} (${cat!.label})'),
                  _Row('กิจกรรม', _activityNames[(p['activity_level'] as num?)?.toInt()] ?? '-'),
                  _Row('เป้าหมาย', _goalNames[p['goal']] ?? '-'),
                  _Row('แคลอรี่ต่อวัน',
                      app.dailyGoal == null ? '-' : '${fmtInt(app.dailyGoal!)} kcal', strong: true),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock_outline, color: kInk),
                    title: const Text('เปลี่ยนรหัสผ่าน'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showDialog<void>(context: context, builder: (_) => const _ChangePasswordDialog()),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  ListTile(
                    leading: const Icon(Icons.logout, color: kRedText),
                    title: const Text('ออกจากระบบ', style: TextStyle(color: kRedText)),
                    onTap: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('ออกจากระบบ?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ยกเลิก')),
                            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('ออกจากระบบ')),
                          ],
                        ),
                      );
                      if (ok == true) await app.logout();
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  const _Row(this.label, this.value, {this.strong = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: kMuted))),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: strong ? 16 : 14,
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                  color: strong ? kGreenText : kInk,
                )),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AppState.instance.changePassword(_current.text, _new.text);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text('เปลี่ยนรหัสผ่านแล้ว'), behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('เปลี่ยนรหัสผ่าน'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'รหัสผ่านปัจจุบัน'),
              validator: (v) => (v == null || v.isEmpty) ? 'กรอกรหัสผ่านปัจจุบัน' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _new,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'รหัสผ่านใหม่ (อย่างน้อย 8 ตัว)'),
              validator: (v) => (v == null || v.length < 8) ? 'อย่างน้อย 8 ตัว' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('ยกเลิก')),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('บันทึก'),
        ),
      ],
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog();

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: AppState.instance.username);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final name = cleanUsername(_name.text);
    if (name == AppState.instance.username) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppState.instance.changeUsername(name);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text('เปลี่ยนชื่อแล้ว'), behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('แก้ชื่อที่แสดง'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(helperText: 'ภาษาไทยหรืออังกฤษ ห้ามซ้ำกับคนอื่น'),
              validator: validateUsername,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: kRedText, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('ยกเลิก')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('บันทึก')),
      ],
    );
  }
}
