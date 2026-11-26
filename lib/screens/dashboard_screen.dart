import 'package:material_ui/material_ui.dart';

import '../data/foods.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'auth_screens.dart';
import 'exercise_sheet.dart';

/// สีของแต่ละมื้อ ใช้ร่วมกันหลายหน้า
const Map<String, Color> kMealColors = {
  'breakfast': kBlue,
  'lunch': kGreen,
  'dinner': kPurple,
  'snack': kOrange,
};

class DashboardScreen extends StatelessWidget {
  final VoidCallback onScan;
  final VoidCallback onOpenMonth;
  const DashboardScreen({super.key, required this.onScan, required this.onOpenMonth});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final goal = app.dailyGoal ?? 0;
        final eaten = app.todayCalories;
        final burned = app.todayBurned;
        // ออกกำลังกายแล้วกินได้เพิ่มตามที่เผาผลาญ (เป้าวันนี้ = เป้า + เผาผลาญ)
        final budget = goal + burned;
        final left = budget - eaten;
        final now = DateTime.now();
        return RefreshIndicator(
          color: kGreenDark,
          onRefresh: () async {
            try {
              await app.refreshMe();
              await app.refreshToday();
            } catch (e) {
              if (context.mounted) showApiError(context, e);
            }
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _Header(name: app.username, date: fmtThaiDate(now), goal: app.profile?['goal'] as String?),
              const SizedBox(height: 14),
              _TodayCard(goal: goal, eaten: eaten, burned: burned, left: left, app: app),
              const SizedBox(height: 14),
              _Alerts(app: app),
              const SizedBox(height: 14),
              ExerciseCard(app: app),
              const SizedBox(height: 14),
              _Last7Days(goal: goal, days: app.last7),
              const SizedBox(height: 14),
              _BodyCard(app: app),
              const SizedBox(height: 14),
              _TodayMeals(meals: app.todayMeals, onScan: onScan, onOpenMonth: onOpenMonth),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String name;
  final String date;
  final String? goal;
  const _Header({required this.name, required this.date, required this.goal});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greet = hour < 12 ? 'สวัสดีตอนเช้า' : (hour < 17 ? 'สวัสดีตอนบ่าย' : 'สวัสดีตอนเย็น');
    final goalText = switch (goal) {
      'lose' => 'เป้าหมาย: ลดน้ำหนัก',
      'gain' => 'เป้าหมาย: เพิ่มน้ำหนัก',
      _ => 'เป้าหมาย: รักษาน้ำหนัก',
    };
    final target = targetText(AppState.instance.profile ?? const {});
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(date, style: const TextStyle(fontSize: 13, color: kMuted)),
        const SizedBox(height: 2),
        Text('$greet, $name',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kInk)),
        const SizedBox(height: 2),
        Text(target == null ? goalText : '$goalText · $target',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kGreenText)),
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  final double goal;
  final double eaten;
  final double burned;
  final double left;
  final AppState app;
  const _TodayCard({
    required this.goal,
    required this.eaten,
    required this.burned,
    required this.left,
    required this.app,
  });

  @override
  Widget build(BuildContext context) {
    final budget = goal + burned;
    final over = left < 0;
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              CalorieRing(eaten: eaten, goal: budget, size: 156),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(over ? 'กินเกินไปแล้ว' : 'เหลือกินได้อีก',
                        style: const TextStyle(fontSize: 15, color: kMuted)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('${fmtInt(left.abs())} kcal',
                          style: TextStyle(
                              fontSize: 34, fontWeight: FontWeight.w800, color: over ? kOrangeText : kGreenText)),
                    ),
                    const SizedBox(height: 8),
                    // สูตรแบบอ่านง่าย: เป้า + ออกกำลังกาย − กินไปแล้ว = เหลือ
                    // ทุกบรรทัดอยู่บรรทัดเดียว จอแคบจะย่อตัวอักษรทั้งกลุ่มเท่ากันแทนการตัดบรรทัด
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SumRow('เป้าวันนี้', fmtInt(goal)),
                          if (burned > 0) _SumRow('+ ออกกำลังกาย', fmtInt(burned)),
                          _SumRow('− กินไปแล้ว', fmtInt(eaten)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _MealBar(goal: budget, app: app),
        ],
      ),
    );
  }
}

class _SumRow extends StatelessWidget {
  final String label;
  final String value;
  const _SumRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.5);
    // ความกว้างคงที่ทุกบรรทัด ตัวเลขชิดขวาตรงกัน (FittedBox ด้านนอกย่อทั้งกลุ่มเมื่อจอแคบ)
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 118, child: Text(label, maxLines: 1, softWrap: false, style: style)),
        SizedBox(
          width: 64,
          child: Text(value,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.right,
              style: style.copyWith(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _MealBar extends StatelessWidget {
  final double goal;
  final AppState app;
  const _MealBar({required this.goal, required this.app});

  @override
  Widget build(BuildContext context) {
    final total = goal <= 0 ? 1.0 : goal;
    final parts = [
      for (final m in kMealThai.keys) (m, app.caloriesForMeal(m)),
    ];
    final eaten = parts.fold(0.0, (s, p) => s + p.$2);
    final restFlex = ((total - eaten).clamp(0.0, total) / total * 1000).round();
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                for (final p in parts)
                  if (p.$2 > 0) Expanded(flex: (p.$2 / total * 1000).round().clamp(1, 100000).toInt(), child: Container(color: kMealColors[p.$1])),
                if (restFlex > 0) Expanded(flex: restFlex, child: Container(color: const Color(0xFFEEF2F6))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final p in parts) LegendDot(kMealColors[p.$1]!, '${kMealThai[p.$1]} ${fmtInt(p.$2)}'),
          ],
        ),
      ],
    );
  }
}

/// การ์ดเตือนสุขภาพ จาก /api/dashboard/alerts
class _Alerts extends StatelessWidget {
  final AppState app;
  const _Alerts({required this.app});

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      if (app.dashboardError != null)
        AlertCard(level: AlertLevel.info, title: 'โหลดการแจ้งเตือนไม่ได้', detail: app.dashboardError!),
      for (final a in app.alerts)
        AlertCard(level: alertLevelFrom(a.level), title: a.title, detail: a.detail),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('การแจ้งเตือน'),
        const SizedBox(height: 10),
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          cards[i],
        ],
      ],
    );
  }
}

class _Last7Days extends StatelessWidget {
  final double goal;
  final List<DayTotal> days;
  const _Last7Days({required this.goal, required this.days});

  static const _weekday = ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.', 'อา.'];

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    final values = days.map((d) => d.calories).toList();
    final labels = [
      for (var i = 0; i < days.length; i++) i == days.length - 1 ? 'วันนี้' : _weekday[days[i].date.weekday - 1],
    ];
    final past = values.take(values.length - 1).where((c) => c > 0).toList();
    final avg = past.isEmpty ? 0.0 : past.reduce((a, b) => a + b) / past.length;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('7 วันล่าสุด'),
          const SizedBox(height: 4),
          Text(
            past.isEmpty
                ? 'ยังไม่มีบันทึกย้อนหลัง'
                : 'เฉลี่ย ${fmtInt(avg)} kcal/วัน หักออกกำลังกายแล้ว (เฉพาะวันที่บันทึก ไม่รวมวันนี้)',
            style: const TextStyle(fontSize: 12, color: kMuted),
          ),
          const SizedBox(height: 14),
          CalorieBars(values: values, labels: labels, goal: goal <= 0 ? 2000 : goal, highlightLast: 1),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              LegendDot(kOrange, 'เกินเป้า'),
              LegendDot(kGreen, 'ไม่เกินเป้า'),
              LegendDot(Color(0xFFCBD5E1), 'วันนี้ (ยังไม่จบวัน)'),
            ],
          ),
        ],
      ),
    );
  }
}

class _BodyCard extends StatelessWidget {
  final AppState app;
  const _BodyCard({required this.app});

  @override
  Widget build(BuildContext context) {
    final weight = (app.profile?['weight'] as num?)?.toDouble();
    final bmi = app.bmi;
    final cat = bmi == null ? null : bmiCategory(bmi);
    return AppCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: StatTile(
                  label: 'น้ำหนัก',
                  value: weight == null ? '-' : '${weight.toStringAsFixed(1)} กก.',
                ),
              ),
              Container(width: 1, height: 64, color: kBorder, margin: const EdgeInsets.symmetric(horizontal: 12)),
              Expanded(
                child: StatTile(
                  label: 'BMI',
                  value: bmi == null ? '-' : bmi.toStringAsFixed(1),
                  sub: cat?.label,
                  subColor: cat?.color,
                ),
              ),
            ],
          ),
          if (_TargetProgress.of(app.profile) != null) ...[
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            _TargetProgress.of(app.profile)!,
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _updateWeight(context, weight),
              icon: const Icon(Icons.monitor_weight_outlined),
              label: const Text('อัปเดตน้ำหนัก'),
            ),
          ),
          const SizedBox(height: 6),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('ใช้วาดกราฟ แจ้งเตือนน้ำหนักลด/ขึ้นเร็ว และคำนวณความคืบหน้าสู่เป้าหมาย',
                style: TextStyle(fontSize: 12, color: kMuted)),
          ),
        ],
      ),
    );
  }

  /// อัปเดตน้ำหนักอย่างเดียว (ส่งแค่ weight: เป้าหมายและวันครบกำหนดเดิมไม่เปลี่ยน)
  Future<void> _updateWeight(BuildContext context, double? current) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => _WeightDialog(current: current));
    if (saved == true && context.mounted) showSnack(context, 'อัปเดตน้ำหนักแล้ว');
  }
}

class _WeightDialog extends StatefulWidget {
  final double? current;
  const _WeightDialog({this.current});

  @override
  State<_WeightDialog> createState() => _WeightDialogState();
}

class _WeightDialogState extends State<_WeightDialog> {
  late final _ctrl = TextEditingController(text: widget.current == null ? '' : fmtKg(widget.current!));
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final w = double.tryParse(_ctrl.text.trim());
    if (w == null || w < 20 || w > 300) {
      setState(() => _error = 'น้ำหนักต้องอยู่ระหว่าง 20–300 กก.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppState.instance.saveProfile({'weight': w});
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
      title: const Text('อัปเดตน้ำหนัก'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: 'น้ำหนักวันนี้', suffixText: 'กก.', errorText: _error),
        onSubmitted: (_) => _busy ? null : _save(),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('บันทึก')),
      ],
    );
  }
}

/// ความคืบหน้าสู่น้ำหนักเป้าหมาย: เริ่ม → ตอนนี้ → เป้า และช้า/เร็วกว่าแผน (จาก target_progress ของ backend)
class _TargetProgress extends StatelessWidget {
  final double start;
  final double now;
  final double target;
  final double done;
  final double remaining;
  final int percent;
  final double behind;
  final bool reached;
  final int daysLeft;
  const _TargetProgress({
    required this.start,
    required this.now,
    required this.target,
    required this.done,
    required this.remaining,
    required this.percent,
    required this.behind,
    required this.reached,
    required this.daysLeft,
  });

  static _TargetProgress? of(Map<String, dynamic>? profile) {
    final p = profile?['target_progress'];
    final target = (profile?['target_weight'] as num?)?.toDouble();
    final now = (profile?['weight'] as num?)?.toDouble();
    final days = (profile?['target_days_left'] as num?)?.toInt();
    if (p is! Map || target == null || now == null || days == null) return null;
    return _TargetProgress(
      start: (p['start_weight'] as num).toDouble(),
      now: now,
      target: target,
      done: (p['done_kg'] as num).toDouble(),
      remaining: (p['remaining_kg'] as num).toDouble(),
      percent: (p['percent'] as num).toInt(),
      behind: (p['behind_kg'] as num).toDouble(),
      reached: p['reached'] == true,
      daysLeft: days,
    );
  }

  @override
  Widget build(BuildContext context) {
    final verb = target < start ? 'ลด' : 'เพิ่ม';
    final (String status, Color color) = reached
        ? ('ถึงน้ำหนักเป้าหมายแล้ว', kGreenText)
        : done < 0
            ? ('น้ำหนัก${verb == 'ลด' ? 'ขึ้น' : 'ลง'}สวนทางเป้า ${fmtKg(-done)} กก.', kRedText)
            : behind >= 0.5
                ? ('ช้ากว่าแผน ${fmtKg(behind)} กก. ลองกินให้ตรงเป้าแคลอรี่', kOrangeText)
                : behind <= -0.5
                    ? ('เร็วกว่าแผน ${fmtKg(-behind)} กก.', kGreenText)
                    : ('เป็นไปตามแผน', kGreenText);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('เป้าหมาย ${fmtKg(target)} กก.',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kInk)),
            ),
            Text(daysLeft > 0 ? 'อีก $daysLeft วัน' : 'ครบกำหนดแล้ว',
                style: const TextStyle(fontSize: 13, color: kMuted)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percent / 100,
            minHeight: 10,
            backgroundColor: const Color(0xFFEEF2F6),
            color: kGreen,
          ),
        ),
        const SizedBox(height: 8),
        Text('$verbไปแล้ว ${fmtKg(done <= 0 ? 0.0 : done)} กก. ($percent%) · เหลืออีก ${fmtKg(remaining)} กก.',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kInk)),
        const SizedBox(height: 2),
        Text('เริ่ม ${fmtKg(start)} → ตอนนี้ ${fmtKg(now)} → เป้า ${fmtKg(target)} กก.',
            style: const TextStyle(fontSize: 13, color: kMuted)),
        const SizedBox(height: 2),
        Text(status, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

class _TodayMeals extends StatelessWidget {
  final List<MealLog> meals;
  final VoidCallback onScan;
  final VoidCallback onOpenMonth;
  const _TodayMeals({required this.meals, required this.onScan, required this.onOpenMonth});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            'วันนี้กินอะไรไปบ้าง',
            trailing: TextButton(
              onPressed: onOpenMonth,
              child: const Text('สรุปทั้งเดือน', style: TextStyle(fontWeight: FontWeight.w700, color: kGreenText)),
            ),
          ),
          if (meals.isEmpty) ...[
            const SizedBox(height: 8),
            const Text('ยังไม่มีมื้อที่บันทึกวันนี้', style: TextStyle(fontSize: 14, color: kMuted)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onScan,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('สแกนอาหารมื้อแรก'),
              ),
            ),
          ] else
            for (var i = 0; i < meals.length; i++) ...[
              if (i > 0) const Divider(color: Color(0xFFF1F5F9), height: 20),
              _MealRow(meal: meals[i]),
            ],
        ],
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  final MealLog meal;
  const _MealRow({required this.meal});

  Future<void> _confirmDelete(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ลบมื้อนี้?'),
        content: Text('${meal.foodName} (${mealLabel(meal.mealType)} ${fmtTime(meal.loggedAt)})'),
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
      await AppState.instance.deleteMeal(meal.logId);
    } catch (e) {
      if (context.mounted) showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = kMealColors[meal.mealType] ?? kGreen;
    final kcal = meal.calories;
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
          child: Text(fmtTime(meal.loggedAt),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kInk)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(meal.foodName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kInk)),
              Text('${mealLabel(meal.mealType)} · ${fmtInt(meal.grams)} กรัม',
                  style: const TextStyle(fontSize: 12, color: kMuted)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(kcal == null ? 'ไม่มีข้อมูล' : fmtInt(kcal),
            style: TextStyle(
                fontSize: kcal == null ? 12 : 15, fontWeight: FontWeight.w700, color: kcal == null ? kMuted : kInk)),
        IconButton(
          tooltip: 'ลบมื้อนี้',
          onPressed: () => _confirmDelete(context),
          icon: const Icon(Icons.delete_outline, color: kMuted, size: 20),
        ),
      ],
    );
  }
}
