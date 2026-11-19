import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import '../util.dart';

/// การ์ดพื้นขาวมุมมน ใช้ทั้งแอป
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color? borderColor;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = Colors.white,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: borderColor == null ? null : Border.all(color: borderColor!),
        boxShadow: const [BoxShadow(color: Color(0x0F0F172A), blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: child,
    );
  }
}

/// หัวข้อการ์ด + ปุ่มด้านขวา (ถ้ามี)
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kInk)),
        ),
        ?trailing,
      ],
    );
  }
}

/// ป้าย "ตัวอย่าง" บอกว่าเป็นข้อมูลจำลอง ยังไม่ได้มาจาก backend
class SampleBadge extends StatelessWidget {
  const SampleBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: const Color(0xFFEEF2F6), borderRadius: BorderRadius.circular(99)),
      child: const Text('ข้อมูลตัวอย่าง', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kMuted)),
    );
  }
}

enum AlertLevel { danger, warning, info, good }

AlertLevel alertLevelFrom(String level) => switch (level) {
      'danger' => AlertLevel.danger,
      'warning' => AlertLevel.warning,
      'good' => AlertLevel.good,
      _ => AlertLevel.info,
    };

/// การ์ดเตือนสุขภาพ 3 ระดับ
class AlertCard extends StatelessWidget {
  final AlertLevel level;
  final String title;
  final String detail;
  const AlertCard({super.key, required this.level, required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg, label, icon) = switch (level) {
      AlertLevel.danger => (kRedBg, const Color(0xFFF7C5C2), kRedText, 'อันตราย', Icons.error_outline),
      AlertLevel.warning => (kOrangeBg, const Color(0xFFFBD7A6), kOrangeText, 'ระวัง', Icons.warning_amber_rounded),
      AlertLevel.info => (const Color(0xFFEAF1FE), const Color(0xFFC6D9FB), const Color(0xFF1A56C4), 'แนะนำ', Icons.info_outline),
      AlertLevel.good => (Colors.white, const Color(0xFFCDEEDC), kGreenText, 'ดี', Icons.check_circle_outline),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
                const SizedBox(height: 2),
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kInk, height: 1.4)),
                const SizedBox(height: 4),
                Text(detail, style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// วงแหวนแคลอรี่วันนี้
class CalorieRing extends StatelessWidget {
  final double eaten;
  final double goal;
  final double size;
  const CalorieRing({super.key, required this.eaten, required this.goal, this.size = 132});

  @override
  Widget build(BuildContext context) {
    final ratio = goal <= 0 ? 0.0 : eaten / goal;
    final over = ratio > 1;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(ratio.clamp(0.0, 1.0), over ? kOrange : kGreen),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(fmtInt(eaten), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kInk, height: 1.1)),
              Text('/ ${fmtInt(goal)} kcal', style: const TextStyle(fontSize: 12, color: kMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double ratio;
  final Color color;
  _RingPainter(this.ratio, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 13.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final bg = Paint()
      ..color = kGreenBg
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, bg);
    if (ratio > 0) {
      canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * ratio, false, fg);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.ratio != ratio || old.color != color;
}

/// กราฟแท่งแคลอรี่รายวัน + เส้นเป้าหมาย
class CalorieBars extends StatelessWidget {
  final List<double> values;
  final List<String>? labels;
  final double goal;
  final double height;
  final int? highlightLast; // แท่งสุดท้าย = วันนี้ (ยังไม่จบวัน)
  const CalorieBars({
    super.key,
    required this.values,
    required this.goal,
    this.labels,
    this.height = 150,
    this.highlightLast,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = [goal * 1.3, ...values].reduce(math.max);
    final goalFromBottom = height * goal / maxValue;
    final gap = values.length > 10 ? 3.0 : 10.0;
    return Column(
      children: [
        SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < values.length; i++) ...[
                      if (i > 0) SizedBox(width: gap),
                      Expanded(
                        child: Container(
                          height: math.max(4.0, height * values[i] / maxValue),
                          decoration: BoxDecoration(
                            color: (highlightLast != null && i == values.length - 1)
                                ? const Color(0xFFCBD5E1)
                                : (values[i] > goal ? kOrange : kGreen),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: goalFromBottom,
                child: Container(height: 2, color: kGreenDark.withValues(alpha: 0.7)),
              ),
              Positioned(
                right: 0,
                bottom: goalFromBottom + 4,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text('เป้า ${fmtInt(goal)}', style: const TextStyle(fontSize: 11, color: kGreenText)),
                ),
              ),
            ],
          ),
        ),
        if (labels != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < labels!.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(
                  child: Text(
                    labels![i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: i == labels!.length - 1 ? kInk : kMuted,
                      fontWeight: i == labels!.length - 1 ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// จุดสี + ข้อความ ใช้เป็น legend
class LegendDot extends StatelessWidget {
  final Color color;
  final String text;
  const LegendDot(this.color, this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
      ],
    );
  }
}

/// ตัวเลขใหญ่ + คำอธิบาย
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? subColor;
  const StatTile({super.key, required this.label, required this.value, this.sub, this.subColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: kMuted)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kInk)),
        if (sub != null)
          Text(sub!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subColor ?? kMuted)),
      ],
    );
  }
}
