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
    _weight.addListener(_schedulePreview);
    _height.addListener(_schedulePreview);
    WidgetsBinding.instance.addPostFrameCallback((_) => _schedulePreview());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _weight.dispose();
    _height.dispose();
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
      _heightError == null;

  Map<String, dynamic> get _fields => {
        'gender': _gender,
        'birth_date': _birthDate == null
            ? null
            : '${_birthDate!.year.toString().padLeft(4, '0')}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}',
        'weight': _w,
        'height': _h,
        'activity_level': _activity,
        'goal': _goal,
      };

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
      _goal = allowed.contains('maintain') ? 'maintain' : allowed.first;
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
      if (mounted) setState(() => _preview = data);
    } on ApiException {
      if (mounted) setState(() => _preview = null);
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
      await AppState.instance.saveProfile(_fields);
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
                        _goal = _goals[i].$1;
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
            const SizedBox(height: 20),
            _PreviewCard(preview: _preview, loading: _previewLoading, complete: _complete),
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
  const _PreviewCard({required this.preview, required this.loading, required this.complete});

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
                  const Text('คำนวณไม่ได้ ลองใหม่อีกครั้ง',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white))
                else ...[
                  Text('${fmtInt(kcal)} kcal',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                  if (_changeText(preview) != null)
                    Text(_changeText(preview)!, style: const TextStyle(fontSize: 12, color: Colors.white)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
