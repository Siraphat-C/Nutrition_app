import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../api/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'auth_screens.dart';

/// ระดับกิจกรรม 1-5 ตรงกับ backend (ตัวคูณ 1.2 / 1.375 / 1.55 / 1.725 / 1.9)
/// นับเฉพาะกิจกรรมในชีวิตประจำวัน ไม่รวมการออกกำลังกาย
/// (การออกกำลังกายนับจากที่ผู้ใช้บันทึกเอง จะได้ไม่นับซ้ำสองครั้ง)
const _activities = [
  (1, 'นั่งเป็นหลัก', 'ทำงานโต๊ะ เรียน แทบไม่ได้เดิน'),
  (2, 'ยืนหรือเดินบ้าง', 'นั่งเป็นส่วนใหญ่ มีเดินไปมาบ้าง'),
  (3, 'ยืนหรือเดินเกือบทั้งวัน', 'เช่น ครู พนักงานขาย พยาบาล'),
  (4, 'งานใช้แรง', 'เช่น ยกของ งานก่อสร้างเบา'),
  (5, 'งานใช้แรงหนัก', 'เช่น แบกหาม งานเกษตร ทั้งวัน'),
];

const _goals = [
  ('lose', 'ลดน้ำหนัก', Icons.trending_down_rounded),
  ('maintain', 'รักษาน้ำหนัก', Icons.trending_flat_rounded),
  ('gain', 'เพิ่มน้ำหนัก', Icons.trending_up_rounded),
];

/// กรอกข้อมูลร่างกายและเป้าหมาย ใช้ทั้งตอนสมัครใหม่และตอนแก้ไขจากโปรไฟล์
class SetupScreen extends StatefulWidget {
  final bool editing;
  const SetupScreen({super.key, this.editing = false});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _weight = TextEditingController();
  final _height = TextEditingController();
  // น้ำหนักเป้าหมาย + ภายในกี่สัปดาห์ (ไม่บังคับ ไม่ใส่ = ลด 500 / เพิ่ม 300 kcal ต่อวันตามเดิม)
  final _target = TextEditingController();
  final _weeks = TextEditingController();
  bool _targetDirty = false;   // ผู้ใช้แก้ตัวเลขเป้าหมายจริง (แค่แตะช่องไม่นับ)
  bool _hadTarget = false;
  String _initTarget = '', _initWeeks = '', _initGoal = 'maintain';
  String _lastTarget = '', _lastWeeks = '';
  String? _previewError;
  String? _gender;
  DateTime? _birthDate;
  int _activity = 2;
  String _goal = 'maintain';

  Map<String, dynamic>? _preview;
  bool _previewLoading = false;
  bool _saving = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final p = AppState.instance.profile ?? {};
    _gender = p['gender'] as String?;
    _birthDate = DateTime.tryParse('${p['birth_date']}');
    if (p['weight'] != null) _weight.text = _trim('${p['weight']}');
    if (p['height'] != null) _height.text = _trim('${p['height']}');
    _activity = (p['activity_level'] as num?)?.toInt() ?? 2;
    _goal = (p['goal'] as String?) ?? 'maintain';
    if (p['target_active'] == true && p['target_weight'] != null) {
      _hadTarget = true;
      _target.text = _trim('${p['target_weight']}');
      final days = (p['target_days_left'] as num?)?.toInt() ?? 0;
      _weeks.text = '${(days / 7).ceil().clamp(1, 104)}';
    }
    _initTarget = _lastTarget = _target.text;
    _initWeeks = _lastWeeks = _weeks.text;
    _initGoal = _goal;
    _weight.addListener(_schedulePreview);
    _height.addListener(_schedulePreview);
    _target.addListener(_onTargetEdited);
    _weeks.addListener(_onTargetEdited);
    WidgetsBinding.instance.addPostFrameCallback((_) => _schedulePreview());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _weight.dispose();
    _height.dispose();
    _target.dispose();
    _weeks.dispose();
    super.dispose();
  }

  static String _trim(String s) => s.endsWith('.0') ? s.substring(0, s.length - 2) : s;

  double? get _w => double.tryParse(_weight.text.trim());
  double? get _h => double.tryParse(_height.text.trim());

  String? get _weightError {
    final w = _w;
    if (_weight.text.trim().isEmpty) return null;
    if (w == null || w < 20 || w > 300) return 'น้ำหนักต้องอยู่ระหว่าง 20–300 กก.';
    return null;
  }

  void _onTargetEdited() {
    // controller แจ้งทุกครั้งที่เลื่อนเคอร์เซอร์ด้วย จึงนับเฉพาะตอนตัวเลขเปลี่ยน
    if (_target.text == _lastTarget && _weeks.text == _lastWeeks) return;
    _lastTarget = _target.text;
    _lastWeeks = _weeks.text;
    _targetDirty = _target.text != _initTarget || _weeks.text != _initWeeks;
    _schedulePreview();
  }

  /// เปลี่ยนเป้าหมาย: ล้างน้ำหนักเป้าหมายเดิม (เป้าลดน้ำหนักใช้กับเพิ่มน้ำหนักไม่ได้)
  void _setGoal(String goal) {
    if (goal == _goal) return;
    _goal = goal;
    if (_target.text.isNotEmpty || _weeks.text.isNotEmpty) {
      _target.clear();
      _weeks.clear();
    }
  }

  double? get _t => double.tryParse(_target.text.trim());
  int? get _wk => int.tryParse(_weeks.text.trim());
  bool get _targetEmpty => _target.text.trim().isEmpty && _weeks.text.trim().isEmpty;

  /// ช่วงน้ำหนักเป้าหมายที่ตั้งได้: ลดได้ไม่ต่ำกว่า BMI 18.5, เพิ่มได้ไม่ถึง BMI 23 (ตรงกับ backend)
  (double, double)? get _targetRange {
    final h = _h;
    if (h == null || _heightError != null) return null;
    final m2 = (h / 100) * (h / 100);
    return ((18.5 * m2 * 10).ceil() / 10, ((23 * m2 - 0.01) * 10).floor() / 10);
  }

  /// จำนวนสัปดาห์น้อยสุด (เปลี่ยนน้ำหนักได้ไม่เกิน 1 กก./สัปดาห์)
  int? get _minWeeks {
    final w = _w, t = _t;
    if (w == null || t == null) return null;
    final diff = ((t - w).abs() * 100).round() / 100;
    return diff <= 0 ? 1 : diff.ceil();
  }

  String? get _targetError {
    // ตรวจเฉพาะตอนผู้ใช้แก้ เป้าเดิมที่ทำช้ากว่าแผนต้องไม่ทำให้บันทึกข้อมูลอื่นไม่ได้
    if (!_targetDirty || _goal == 'maintain' || _targetEmpty) return null;
    final w = _w, t = _t, wk = _wk, range = _targetRange;
    if (t == null || wk == null) return 'ใส่ทั้งน้ำหนักเป้าหมายและจำนวนสัปดาห์';
    if (w == null || range == null) return null;
    if (wk < 1 || wk > 104) return 'ระยะเวลา 1–104 สัปดาห์';
    if (_goal == 'lose') {
      if (t >= w) return 'น้ำหนักเป้าหมายต้องน้อยกว่าตอนนี้ (${_trim('$w')} กก.)';
      if (t < range.$1) return 'ต่ำสุด ${range.$1} กก. (BMI 18.5) ต่ำกว่านี้ผอมเกินไป';
    } else {
      if (t <= w) return 'น้ำหนักเป้าหมายต้องมากกว่าตอนนี้ (${_trim('$w')} กก.)';
      if (t > range.$2) return 'สูงสุด ${range.$2} กก. (BMI ต่ำกว่า 23)';
    }
    final need = _minWeeks ?? 1;
    if (wk < need) return 'เร็วเกินไป ต้องใช้อย่างน้อย $need สัปดาห์ (ไม่เกิน 1 กก./สัปดาห์)';
    return null;
  }

  bool get _hasValidTarget => _targetDirty && _goal != 'maintain' && !_targetEmpty && _targetError == null;

  /// เป้าเดิมที่ยังใช้อยู่และผู้ใช้ไม่ได้แก้
  bool get _keepTarget => _hadTarget && !_targetDirty && _goal == _initGoal;

  String? get _heightError {
    final h = _h;
    if (_height.text.trim().isEmpty) return null;
    if (h == null || h < 100 || h > 250) return 'ส่วนสูงต้องอยู่ระหว่าง 100–250 ซม.';
    return null;
  }

  bool get _complete =>
      _gender != null &&
      _birthDate != null &&
      _w != null &&
      _h != null &&
      _weightError == null &&
      _heightError == null &&
      _targetError == null;

  Map<String, dynamic> get _fields => {
        'gender': _gender,
        'birth_date': _birthDate == null
            ? null
            : '${_birthDate!.year.toString().padLeft(4, '0')}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}',
        'weight': _w,
        'height': _h,
        'activity_level': _activity,
        'goal': _goal,
        if (_hasValidTarget) ...{'target_weight': _t, 'target_weeks': _wk},
        if (_keepTarget) 'keep_target': true,
      };

  /// ส่งตอนบันทึก: ส่งน้ำหนักเป้าหมายเฉพาะตอนแก้ (ไม่แก้ = วันครบกำหนดเดิมไม่เลื่อน)
  Map<String, dynamic> get _saveFields {
    final f = Map<String, dynamic>.from(_fields)..remove('keep_target');
    if (!_targetDirty) {
      f.remove('target_weight');
      f.remove('target_weeks');
    } else if (_hadTarget && !_hasValidTarget) {
      f['clear_target'] = true;
    }
    return f;
  }

  double? get _bmi {
    final w = _w, h = _h;
    if (w == null || h == null || _weightError != null || _heightError != null) return null;
    return w / ((h / 100) * (h / 100));
  }

  List<String> get _allowedGoals => allowedGoalsForBmi(_bmi);

  void _schedulePreview() {
    // น้ำหนัก/ส่วนสูงเปลี่ยนจนเป้าหมายเดิมเลือกไม่ได้ ให้กลับไปที่ "รักษาน้ำหนัก"
    // ถ้ารักษาน้ำหนักก็เลือกไม่ได้ (BMI เกินเกณฑ์) ให้ใช้ตัวแรกที่เลือกได้ คือ "ลดน้ำหนัก"
    final allowed = _allowedGoals;
    if (!allowed.contains(_goal)) {
      _setGoal(allowed.contains('maintain') ? 'maintain' : allowed.first);
    }
    setState(() {});
    _debounce?.cancel();
    if (!_complete) {
      setState(() => _preview = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), _loadPreview);
  }

  Future<void> _loadPreview() async {
    setState(() => _previewLoading = true);
    try {
      final data = await AppState.instance.api.previewRequirement(_fields);
      if (mounted) {
        setState(() {
          _preview = data;
          _previewError = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _preview = null;
          _previewError = e.message;
        });
      }
    } finally {
      if (mounted) setState(() => _previewLoading = false);
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20, 1, 1),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 13, now.month, now.day),
      helpText: 'เลือกวันเกิด',
    );
    if (picked != null) {
      _birthDate = picked;
      _schedulePreview();
    }
  }

  Future<void> _save() async {
    if (!_complete) return;
    setState(() => _saving = true);
    try {
      await AppState.instance.saveProfile(_saveFields);
      if (!mounted) return;
      if (widget.editing) {
        showSnack(context, 'บันทึกข้อมูลแล้ว');
        Navigator.of(context).pop();
      }
      // ตอนสมัครใหม่ main.dart จะพาไปหน้าหลักเองเมื่อข้อมูลครบ
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final age = _birthDate == null ? null : _ageOf(_birthDate!);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing ? 'ข้อมูลร่างกายและเป้าหมาย' : 'ตั้งค่าเริ่มต้น'),
        automaticallyImplyLeading: widget.editing,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            if (!widget.editing) ...[
              const Text('บอกเราเกี่ยวกับตัวคุณ',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kInk)),
              const SizedBox(height: 4),
              const Text('ใช้คำนวณแคลอรี่ที่ควรได้รับต่อวัน แก้ไขภายหลังได้ที่หน้าโปรไฟล์',
                  style: TextStyle(fontSize: 14, color: kMuted, height: 1.5)),
              const SizedBox(height: 20),
            ],
            const _Label('เพศ'),
            Row(
              children: [
                Expanded(child: _ChoiceChip(label: 'ชาย', icon: Icons.male, selected: _gender == 'male', onTap: () {
                  _gender = 'male';
                  _schedulePreview();
                })),
                const SizedBox(width: 12),
                Expanded(child: _ChoiceChip(label: 'หญิง', icon: Icons.female, selected: _gender == 'female', onTap: () {
                  _gender = 'female';
                  _schedulePreview();
                })),
              ],
            ),
            const SizedBox(height: 18),
            const _Label('วันเกิด'),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pickBirthDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cake_outlined, color: kMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _birthDate == null ? 'แตะเพื่อเลือกวันเกิด' : fmtThaiShortDate(_birthDate!),
                        style: TextStyle(fontSize: 15, color: _birthDate == null ? kMuted : kInk),
                      ),
                    ),
                    if (age != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: kGreenBg, borderRadius: BorderRadius.circular(99)),
                        child: Text('อายุ $age ปี',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kGreenText)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('น้ำหนัก (กก.)'),
                      TextField(
                        controller: _weight,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(hintText: 'เช่น 60', errorText: _weightError, errorMaxLines: 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('ส่วนสูง (ซม.)'),
                      TextField(
                        controller: _height,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(hintText: 'เช่น 165', errorText: _heightError, errorMaxLines: 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_bmi != null) ...[
              const SizedBox(height: 12),
              _BmiStrip(bmi: _bmi!),
            ],
            const SizedBox(height: 18),
            const _Label('กิจกรรมในแต่ละวัน'),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('ไม่ต้องนับการออกกำลังกาย ให้บันทึกในการ์ดออกกำลังกายแทน',
                  style: TextStyle(fontSize: 12, color: kMuted, height: 1.4)),
            ),
            for (final a in _activities) ...[
              _OptionRow(
                title: a.$2,
                subtitle: a.$3,
                selected: _activity == a.$1,
                onTap: () {
                  _activity = a.$1;
                  _schedulePreview();
                },
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 10),
            const _Label('เป้าหมาย'),
            Row(
              children: [
                for (var i = 0; i < _goals.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _ChoiceChip(
                      label: _goals[i].$2,
                      icon: _goals[i].$3,
                      selected: _goal == _goals[i].$1,
                      vertical: true,
                      enabled: _allowedGoals.contains(_goals[i].$1),
                      onTap: () {
                        _setGoal(_goals[i].$1);
                        _schedulePreview();
                      },
                    ),
                  ),
                ],
              ],
            ),
            if (_bmi != null && _allowedGoals.length < _goals.length) ...[
              const SizedBox(height: 8),
              Text(
                _bmi! < 18.5
                    ? 'BMI ${_bmi!.toStringAsFixed(1)} ต่ำกว่าเกณฑ์ จึงเลือกลดน้ำหนักไม่ได้'
                    : 'BMI ${_bmi!.toStringAsFixed(1)} เกินเกณฑ์ (23 ขึ้นไป) จึงเลือกได้แค่ลดน้ำหนัก',
                style: const TextStyle(fontSize: 12, color: kMuted, height: 1.4),
              ),
            ],
            if (_goal != 'maintain') ...[
              const SizedBox(height: 18),
              _Label(_goal == 'lose' ? 'อยากลดเหลือกี่กิโล (ไม่บังคับ)' : 'อยากเพิ่มเป็นกี่กิโล (ไม่บังคับ)'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _target,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(hintText: 'น้ำหนักเป้าหมาย', suffixText: 'กก.'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _weeks,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'ภายใน', suffixText: 'สัปดาห์'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _targetError ?? _targetHint(),
                style: TextStyle(fontSize: 12, height: 1.4, color: _targetError != null ? kRedText : kMuted),
              ),
            ],
            const SizedBox(height: 20),
            _PreviewCard(
              preview: _preview,
              loading: _previewLoading,
              complete: _complete,
              error: _previewError,
              targetWeight: _hasValidTarget ? _t : (_keepTarget ? double.tryParse(_initTarget) : null),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: (_complete && !_saving) ? _save : null,
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(widget.editing ? 'บันทึก' : 'บันทึกและเริ่มใช้งาน'),
            ),
          ],
        ),
      ),
    );
  }

  String _targetHint() {
    final range = _targetRange, need = _minWeeks;
    final parts = <String>[
      if (range != null) _goal == 'lose' ? 'ลดได้ต่ำสุด ${range.$1} กก.' : 'เพิ่มได้สูงสุด ${range.$2} กก.',
      if (need != null && _t != null) 'ต้องใช้อย่างน้อย $need สัปดาห์',
      'ไม่ใส่ = ${_goal == 'lose' ? 'ลด' : 'เพิ่ม'}แบบปกติ',
    ];
    return parts.join(' · ');
  }

  static int _ageOf(DateTime birth) {
    final now = DateTime.now();
    var age = now.year - birth.year;
    if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) age--;
    return age;
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kInk)),
      );
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool vertical;
  final bool enabled;
  final VoidCallback onTap;
  const _ChoiceChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.vertical = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? kGreenText : kMuted;
    final children = [
      Icon(icon, color: color, size: 22),
      SizedBox(width: vertical ? 0 : 8, height: vertical ? 6 : 0),
      Flexible(
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: selected ? kGreenText : kInk)),
      ),
    ];
    return Semantics(
      selected: selected,
      button: true,
      enabled: enabled,
      child: Opacity(
        // ปุ่มที่เลือกไม่ได้ตาม BMI จะจางลงและกดไม่ได้
        opacity: enabled ? 1 : 0.35,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onTap : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? kGreenBg : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? kGreen : kBorder, width: selected ? 2 : 1),
            ),
            child: vertical
                ? Column(mainAxisSize: MainAxisSize.min, children: children)
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: children),
          ),
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _OptionRow({required this.title, required this.subtitle, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? kGreenBg : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? kGreen : kBorder, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: selected ? kGreenDark : kMuted, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kInk)),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: kMuted)),
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

class _BmiStrip extends StatelessWidget {
  final double bmi;
  const _BmiStrip({required this.bmi});

  @override
  Widget build(BuildContext context) {
    final cat = bmiCategory(bmi);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
      child: Row(
        children: [
          const Text('BMI', style: TextStyle(fontSize: 13, color: kMuted)),
          const SizedBox(width: 10),
          Text(bmi.toStringAsFixed(1), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kInk)),
          const Spacer(),
          Text(cat.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cat.color)),
        ],
      ),
    );
  }
}

String _trimKg(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// "ลดประมาณ 0.45 กก./สัปดาห์ (1.9 กก./เดือน)" จาก expected_kg_per_week ของ backend
String? _changeText(Map<String, dynamic>? preview) {
  final week = (preview?['expected_kg_per_week'] as num?)?.toDouble();
  final month = (preview?['expected_kg_per_month'] as num?)?.toDouble();
  if (week == null || month == null || week == 0) return null;
  final verb = week < 0 ? 'ลด' : 'เพิ่ม';
  return 'ถ้ากินตามเป้า น้ำหนักจะ$verbประมาณ ${week.abs().toStringAsFixed(2)} กก./สัปดาห์ '
      '(${month.abs().toStringAsFixed(1)} กก./เดือน)';
}

class _PreviewCard extends StatelessWidget {
  final Map<String, dynamic>? preview;
  final bool loading;
  final bool complete;
  final String? error;
  final double? targetWeight;
  const _PreviewCard({
    required this.preview,
    required this.loading,
    required this.complete,
    this.error,
    this.targetWeight,
  });

  @override
  Widget build(BuildContext context) {
    final kcal = (preview?['daily_calories'] as num?)?.toDouble();
    return AppCard(
      color: kGreenDark,
      child: Row(
        children: [
          const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('แคลอรี่ที่ควรได้รับต่อวัน', style: TextStyle(fontSize: 13, color: Colors.white)),
                const SizedBox(height: 2),
                if (!complete)
                  const Text('กรอกข้อมูลให้ครบเพื่อดูผล',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white))
                else if (loading && kcal == null)
                  const Text('กำลังคำนวณ…',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white))
                else if (kcal == null)
                  Text(error ?? 'คำนวณไม่ได้ ลองใหม่อีกครั้ง',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white))
                else ...[
                  Text('${fmtInt(kcal)} kcal',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                  if (_changeText(preview) != null)
                    Text(_changeText(preview)!, style: const TextStyle(fontSize: 12, color: Colors.white)),
                  if (targetWeight != null && DateTime.tryParse('${preview?['target_date']}') != null)
                    Text(
                      'ถึง ${_trimKg(targetWeight!)} กก. ภายใน ${fmtThaiShortDate(DateTime.parse('${preview!['target_date']}'))}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
