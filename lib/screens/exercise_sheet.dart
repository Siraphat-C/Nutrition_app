import 'package:material_ui/material_ui.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'auth_screens.dart';

/// การ์ดออกกำลังกายวันนี้ (แสดงบนหน้าหลัก)
class ExerciseCard extends StatelessWidget {
  final AppState app;
  const ExerciseCard({super.key, required this.app});

  Future<void> _confirmDelete(BuildContext context, ExerciseLog e) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ลบรายการนี้?'),
        content: Text('${e.name} ${e.minutes} นาที (${fmtTime(e.loggedAt)})'),
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
    if (yes != true) return;
    try {
      await app.deleteExercise(e.id);
    } catch (err) {
      if (context.mounted) showApiError(context, err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = app.todayExercises;
    final total = app.todayBurned;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4E5), Color(0xFFFFE7CC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD8A8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: kOrange, borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('ออกกำลังกายวันนี้',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kOrangeText)),
              ),
              Text('${fmtInt(total)} kcal',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kOrangeText)),
            ],
          ),
          if (items.isEmpty) ...[
            const SizedBox(height: 4),
            const Text('แคลอรี่ที่เผาผลาญจะเพิ่มเข้าไปในแคลอรี่ที่กินได้วันนี้',
                style: TextStyle(fontSize: 12, color: kOrangeText)),
          ],
          if (app.exerciseError != null) ...[
            const SizedBox(height: 8),
            Text(app.exerciseError!, style: const TextStyle(fontSize: 12, color: kRedText)),
          ],
          if (items.isNotEmpty) const SizedBox(height: 12),
          for (final e in items) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(10, 6, 2, 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: kOrangeBg, borderRadius: BorderRadius.circular(12)),
                    child: Icon(activityIcon(e.activity), color: kOrangeText, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kInk)),
                        Text('${e.minutes} นาที · ${fmtTime(e.loggedAt)}',
                            style: const TextStyle(fontSize: 12, color: kMuted)),
                      ],
                    ),
                  ),
                  Text('-${fmtInt(e.caloriesBurned)} kcal',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kOrangeText)),
                  IconButton(
                    tooltip: 'ลบรายการนี้',
                    onPressed: () => _confirmDelete(context, e),
                    icon: const Icon(Icons.delete_outline, color: kMuted, size: 20),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: kOrangeText,
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFFFD8A8)),
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: () => showExerciseSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('บันทึกการออกกำลังกาย'),
            ),
          ),
        ],
      ),
    );
  }
}

/// ไอคอนของแต่ละกิจกรรม (คีย์ตรงกับ exercise.py ใน backend)
IconData activityIcon(String key) => switch (key) {
      'walk' || 'walk_brisk' => Icons.directions_walk_rounded,
      'jogging' || 'running' => Icons.directions_run_rounded,
      'cycling_leisure' || 'cycling' || 'stationary_bike' => Icons.directions_bike_rounded,
      'swimming' => Icons.pool_rounded,
      'football' || 'futsal' => Icons.sports_soccer_rounded,
      'basketball' => Icons.sports_basketball_rounded,
      'badminton' || 'table_tennis' => Icons.sports_tennis_rounded,
      'volleyball' => Icons.sports_volleyball_rounded,
      'muay_thai' => Icons.sports_mma_rounded,
      'yoga' => Icons.self_improvement_rounded,
      _ => Icons.fitness_center_rounded,
    };

Future<void> showExerciseSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => const _ExerciseSheet(),
    );

class _ExerciseSheet extends StatefulWidget {
  const _ExerciseSheet();

  @override
  State<_ExerciseSheet> createState() => _ExerciseSheetState();
}

class _ExerciseSheetState extends State<_ExerciseSheet> {
  static const _quickMinutes = [15, 30, 45, 60];

  final _minutes = TextEditingController(text: '30');
  List<ExerciseActivity> _activities = [];
  ExerciseActivity? _selected;
  String? _loadError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _minutes.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await AppState.instance.loadExerciseActivities();
      if (mounted) setState(() => _activities = list);
    } catch (e) {
      if (mounted) setState(() => _loadError = '$e');
    }
  }

  int? get _mins {
    final v = int.tryParse(_minutes.text.trim());
    if (v == null || v < 1 || v > 600) return null;
    return v;
  }

  double? get _weight => toDouble(AppState.instance.profile?['weight']);

  /// kcal = MET x น้ำหนัก (กก.) x ชั่วโมง (สูตรเดียวกับ backend)
  double? get _estimate {
    final a = _selected, m = _mins, w = _weight;
    if (a == null || m == null || w == null) return null;
    return a.met * w * m / 60;
  }

  Future<void> _save() async {
    final a = _selected, m = _mins;
    if (a == null || m == null) return;
    setState(() => _saving = true);
    try {
      await AppState.instance.addExercise(a.key, m);
      if (!mounted) return;
      showSnack(context, 'บันทึก${a.name} $m นาทีแล้ว');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estimate = _estimate;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('บันทึกการออกกำลังกาย',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kInk)),
          const SizedBox(height: 16),
          if (_loadError != null)
            Text(_loadError!, style: const TextStyle(color: kRedText))
          else if (_activities.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else
            DropdownButtonFormField<ExerciseActivity>(
              initialValue: _selected,
              isExpanded: true,
              hint: const Text('เลือกกิจกรรม'),
              items: [
                for (final a in _activities)
                  DropdownMenuItem(value: a, child: Text('${a.name} (MET ${a.met})')),
              ],
              onChanged: (a) => setState(() => _selected = a),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _minutes,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'ระยะเวลา (นาที)',
              errorText: _minutes.text.trim().isNotEmpty && _mins == null ? 'กรอก 1–600 นาที' : null,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final q in _quickMinutes)
                ChoiceChip(
                  label: Text('$q นาที'),
                  selected: _mins == q,
                  onSelected: (_) => _minutes.text = '$q',
                ),
            ],
          ),
          const SizedBox(height: 16),
          AppCard(
            color: kGreenBg,
            child: Row(
              children: [
                const Icon(Icons.local_fire_department_rounded, color: kGreenText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _weight == null
                        ? 'กรอกน้ำหนักตัวในโปรไฟล์ก่อน จึงจะคำนวณได้'
                        : estimate == null
                            ? 'เลือกกิจกรรมและเวลาเพื่อดูแคลอรี่ที่เผาผลาญ'
                            : 'เผาผลาญ ${fmtInt(estimate)} kcal',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kGreenText),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text('คำนวณจาก MET x น้ำหนักตัว x เวลา (ค่า MET จาก Compendium of Physical Activities 2024)',
              style: TextStyle(fontSize: 11, color: kMuted)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: (estimate != null && !_saving) ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('บันทึก'),
          ),
        ],
      ),
    );
  }
}
