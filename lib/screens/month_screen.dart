import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../data/foods.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'dashboard_screen.dart' show kMealColors;

/// สรุปรายเดือน จาก /api/dashboard/summary และ /api/weight/history
class MonthScreen extends StatefulWidget {
  const MonthScreen({super.key});

  @override
  State<MonthScreen> createState() => _MonthScreenState();
}

class _MonthScreenState extends State<MonthScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, dynamic>? _summary;
  List<WeightPoint> _weights = [];
  bool _loading = false;
  String? _error;

  static const _monthNames = [
    'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
    'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
  ];

  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onAppChanged);
    _load();
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onAppChanged);
    super.dispose();
  }

  int _mealCount = AppState.instance.todayMeals.length;

  // บันทึกมื้อหรือน้ำหนักใหม่ → โหลดสรุปใหม่
  void _onAppChanged() {
    final count = AppState.instance.todayMeals.length;
    if (count != _mealCount) {
      _mealCount = count;
      _load();
    }
  }

  String get _monthKey => '${_month.year.toString().padLeft(4, '0')}-${_month.month.toString().padLeft(2, '0')}';

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = AppState.instance.api;
      final summary = await api.dashboardSummary(_monthKey);
      final weights = await api.weightHistory(days: 120);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _weights = [
          for (final w in weights)
            if (DateTime.tryParse('${w['logged_at']}') != null)
              WeightPoint(DateTime.parse('${w['logged_at']}').toLocal(), toDouble(w['weight']) ?? 0),
        ].where((w) => w.at.year == _month.year && w.at.month == _month.month).toList();
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _shift(int months) {
    setState(() => _month = DateTime(_month.year, _month.month + months));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    return RefreshIndicator(
      color: kGreenDark,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const Text('สรุปรายเดือน', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kInk)),
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton(
                tooltip: 'เดือนก่อน',
                onPressed: _loading ? null : () => _shift(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text('${_monthNames[_month.month - 1]} ${_month.year + 543}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kInk)),
              ),
              IconButton(
                tooltip: 'เดือนถัดไป',
                onPressed: (_loading || _isCurrentMonth) ? null : () => _shift(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading && s == null)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: kGreenDark)),
            )
          else if (_error != null)
            AlertCard(level: AlertLevel.danger, title: 'โหลดสรุปไม่ได้', detail: _error!)
          else if (s != null)
            ..._content(s),
        ],
      ),
    );
  }

  List<Widget> _content(Map<String, dynamic> s) {
    final goal = toDouble(s['goal']) ?? AppState.instance.dailyGoal ?? 2000;
    final daysLogged = (s['days_logged'] as num?)?.toInt() ?? 0;
    if (daysLogged == 0) {
      return const [
        AppCard(
          child: Column(
            children: [
              Icon(Icons.event_note_outlined, size: 40, color: kMuted),
              SizedBox(height: 8),
              Text('เดือนนี้ยังไม่มีมื้อที่บันทึก', style: TextStyle(fontSize: 15, color: kMuted)),
            ],
          ),
        ),
      ];
    }
    final daily = ((s['daily'] as List?) ?? []).map((e) => toDouble((e as Map)['calories']) ?? 0).toList();
    List<FoodStat> foods(String key) => ((s[key] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .map((e) => FoodStat(thaiFoodName(e['food_name'] as String?), (e['times'] as num).toInt(),
            toDouble(e['calories']) ?? 0))
        .toList();
    final byMeal = Map<String, dynamic>.from(s['by_meal'] ?? {});
    final mealParts = [
      for (final k in kMealThai.keys) (k, toDouble(byMeal[k]) ?? 0),
    ].where((p) => p.$2 > 0).toList();

    return [
      AppCard(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: StatTile(label: 'กินไปทั้งหมด', value: '${fmtInt(toDouble(s['total_calories']) ?? 0)} kcal')),
                Expanded(child: StatTile(label: 'เฉลี่ยต่อวัน', value: '${fmtInt(toDouble(s['average_per_day']) ?? 0)} kcal')),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('บันทึก $daysLogged วัน · เป้า ${fmtInt(goal)} kcal/วัน',
                  style: const TextStyle(fontSize: 12, color: kMuted)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _DayCount('เกินเป้า', (s['days_over'] as num?)?.toInt() ?? 0, kOrangeText, kOrangeBg)),
                const SizedBox(width: 8),
                Expanded(child: _DayCount('พอดี', (s['days_on_target'] as num?)?.toInt() ?? 0, kGreenText, kGreenBg)),
                const SizedBox(width: 8),
                Expanded(
                  child: _DayCount('ขาดเป้า', (s['days_under'] as num?)?.toInt() ?? 0, const Color(0xFF1A56C4),
                      const Color(0xFFEAF1FE)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('พอดี = อยู่ในช่วงเป้า ±10% (ไม่นับวันนี้)', style: TextStyle(fontSize: 11, color: kMuted)),
          ],
        ),
      ),
      const SizedBox(height: 14),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('แคลอรี่รายวัน'),
            const SizedBox(height: 12),
            CalorieBars(values: daily, goal: goal, height: 130, highlightLast: _isCurrentMonth ? 1 : null),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('1', style: TextStyle(fontSize: 12, color: kMuted)),
                const Spacer(),
                Text('${daily.length}', style: const TextStyle(fontSize: 12, color: kMuted)),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _RankCard(
        title: 'เมนูที่กินบ่อยที่สุด',
        items: foods('most_frequent'),
        valueOf: (f) => f.times.toDouble(),
        labelOf: (f) => '${f.times} ครั้ง',
      ),
      const SizedBox(height: 14),
      _RankCard(
        title: 'เมนูที่ให้แคลอรี่รวมมากที่สุด',
        items: foods('most_calories'),
        valueOf: (f) => f.calories,
        labelOf: (f) => '${fmtInt(f.calories)} kcal',
      ),
      const SizedBox(height: 14),
      if (mealParts.isNotEmpty) ...[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader('แคลอรี่แยกตามมื้อ'),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 14,
                  child: Row(
                    children: [
                      for (final p in mealParts)
                        Expanded(
                          flex: (p.$2 * 1000).round().clamp(1, 1000).toInt(),
                          child: Container(color: kMealColors[p.$1]),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  for (final p in mealParts) LegendDot(kMealColors[p.$1]!, '${kMealThai[p.$1]} ${(p.$2 * 100).round()}%'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
      _WeightCard(points: _weights),
    ];
  }
}

class FoodStat {
  final String name;
  final int times;
  final double calories;
  const FoodStat(this.name, this.times, this.calories);
}

class WeightPoint {
  final DateTime at;
  final double kg;
  const WeightPoint(this.at, this.kg);
}

class _DayCount extends StatelessWidget {
  final String label;
  final int days;
  final Color fg;
  final Color bg;
  const _DayCount(this.label, this.days, this.fg, this.bg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Text('$days วัน', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: fg)),
          Text(label, style: TextStyle(fontSize: 12, color: fg)),
        ],
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  final String title;
  final List<FoodStat> items;
  final double Function(FoodStat) valueOf;
  final String Function(FoodStat) labelOf;
  const _RankCard({required this.title, required this.items, required this.valueOf, required this.labelOf});

  @override
  Widget build(BuildContext context) {
    final maxValue = items.map(valueOf).fold<double>(0.0, (a, b) => a > b ? a : b);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 22,
                  child: Text('${i + 1}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kMuted)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(items[i].name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kInk)),
                          ),
                          Text(labelOf(items[i]), style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: maxValue <= 0 ? 0 : valueOf(items[i]) / maxValue,
                          minHeight: 8,
                          backgroundColor: const Color(0xFFEEF2F6),
                          color: i == 0 ? kGreenDark : kGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WeightCard extends StatelessWidget {
  final List<WeightPoint> points;
  const _WeightCard({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader('น้ำหนักเดือนนี้'),
            SizedBox(height: 6),
            Text('ยังไม่มีบันทึกน้ำหนักในเดือนนี้ กด "บันทึกน้ำหนักวันนี้" ที่หน้าหลัก',
                style: TextStyle(fontSize: 13, color: kMuted, height: 1.5)),
          ],
        ),
      );
    }
    final first = points.first.kg;
    final last = points.last.kg;
    final diff = last - first;
    final shown = points.length <= 5
        ? points
        : [points.first, points[points.length ~/ 4], points[points.length ~/ 2], points[points.length * 3 ~/ 4], points.last];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('น้ำหนักเดือนนี้'),
          const SizedBox(height: 4),
          Text(
            points.length < 2
                ? '${last.toStringAsFixed(1)} กก.'
                : '${last.toStringAsFixed(1)} กก. (${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)} จากครั้งแรกของเดือน)',
            style: const TextStyle(fontSize: 13, color: kMuted),
          ),
          if (points.length >= 2) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              width: double.infinity,
              child: CustomPaint(painter: _LinePainter(points.map((p) => p.kg).toList())),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final p in shown) Text('${p.at.day}/${p.at.month}', style: const TextStyle(fontSize: 11, color: kMuted)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> values;
  _LinePainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final lo = values.reduce(math.min) - 0.5;
    final hi = values.reduce(math.max) + 0.5;
    Offset at(int i) => Offset(
          size.width * i / (values.length - 1),
          size.height - (values[i] - lo) / (hi - lo) * size.height,
        );
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = kGreenDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
    final dot = Paint()..color = kGreenDark;
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(at(i), 5, Paint()..color = Colors.white);
      canvas.drawCircle(at(i), 4, dot);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.values != values;
}
