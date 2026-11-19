import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util.dart';

final _emailPattern = RegExp(r'^[\w.+\-]+@[\w\-]+\.[\w.\-]+$');

/// โลโก้ + ชื่อแอป ด้านบนหน้าเข้าสู่ระบบ/สมัคร
class _Brand extends StatelessWidget {
  final String subtitle;
  const _Brand(this.subtitle);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: kGreenBg, borderRadius: BorderRadius.circular(22)),
          child: const Icon(Icons.restaurant_rounded, color: kGreenDark, size: 38),
        ),
        const SizedBox(height: 16),
        const Text('วิเคราะห์แคลอรี่จากรูปอาหาร',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kInk)),
        const SizedBox(height: 6),
        Text(subtitle,
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: kMuted, height: 1.5)),
      ],
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppState.instance.login(_email.text.trim(), _password.text);
      // main.dart จะพาไปหน้าถัดไปเองเมื่อสถานะเปลี่ยน
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      // ผลลัพธ์จาก backend ไม่ใช่รูปแบบที่แอปรู้จัก (เช่น รัน backend ผิด branch)
      setState(() => _error = 'อ่านผลจากเซิร์ฟเวอร์ไม่ได้ ตรวจสอบว่ารัน backend จาก branch backend-dev ($e)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Brand('ถ่ายรูปอาหาร แล้ว AI บอกแคลอรี่ให้ทันที'),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'อีเมล', prefixIcon: Icon(Icons.mail_outline)),
                      validator: (v) => (v == null || !_emailPattern.hasMatch(v.trim())) ? 'กรอกอีเมลให้ถูกต้อง' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _hide,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'รหัสผ่าน',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _hide ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                          icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _hide = !_hide),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'กรอกรหัสผ่าน' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      _ErrorBox(_error!),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text('เข้าสู่ระบบ'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('ยังไม่มีบัญชี?', style: TextStyle(color: kMuted)),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                          ),
                          child: const Text('สมัครสมาชิก',
                              style: TextStyle(fontWeight: FontWeight.w700, color: kGreenText)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppState.instance.api.register(cleanUsername(_username.text), _email.text.trim(), _password.text);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _busy = false;
      });
      return;
    } catch (e) {
      setState(() {
        _error = 'อ่านผลจากเซิร์ฟเวอร์ไม่ได้ ตรวจสอบว่ารัน backend จาก branch backend-dev ($e)';
        _busy = false;
      });
      return;
    }
    // สมัครสำเร็จแล้ว ต่อด้วยล็อกอินอัตโนมัติ
    try {
      await AppState.instance.login(_email.text.trim(), _password.text);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).popUntil((r) => r.isFirst);
      messenger.showSnackBar(SnackBar(
        content: Text('สมัครสำเร็จแล้ว แต่เข้าสู่ระบบอัตโนมัติไม่ได้ กรุณาเข้าสู่ระบบอีกครั้ง ($e)'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สมัครสมาชิก')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('สร้างบัญชีใหม่',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kInk)),
                    const SizedBox(height: 4),
                    const Text('ขั้นต่อไปจะถามข้อมูลร่างกาย เพื่อคำนวณแคลอรี่ที่ควรได้รับต่อวัน',
                        style: TextStyle(fontSize: 14, color: kMuted, height: 1.5)),
                    const SizedBox(height: 22),
                    TextFormField(
                      controller: _username,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อที่แสดงในแอป',
                        helperText: 'ภาษาไทยหรืออังกฤษ อย่างน้อย 3 ตัว ห้ามซ้ำกับคนอื่น',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: validateUsername,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'อีเมล', prefixIcon: Icon(Icons.mail_outline)),
                      validator: (v) => (v == null || !_emailPattern.hasMatch(v.trim())) ? 'กรอกอีเมลให้ถูกต้อง' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _hide,
                      decoration: InputDecoration(
                        labelText: 'รหัสผ่าน (อย่างน้อย 8 ตัว)',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _hide ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                          icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _hide = !_hide),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 8) ? 'รหัสผ่านต้องมีอย่างน้อย 8 ตัว' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirm,
                      obscureText: _hide,
                      decoration: const InputDecoration(labelText: 'ยืนยันรหัสผ่าน', prefixIcon: Icon(Icons.lock_outline)),
                      validator: (v) => v != _password.text ? 'รหัสผ่านไม่ตรงกัน' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      _ErrorBox(_error!),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text('สมัครและไปต่อ'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: kRedBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: kRedText, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: kRedText, fontSize: 13))),
        ],
      ),
    );
  }
}

/// ใช้ตอนต้องแสดง error ในหน้าอื่น
void showApiError(BuildContext context, Object e) =>
    showSnack(context, e is ApiException ? e.message : 'เกิดข้อผิดพลาด: $e', error: true);
