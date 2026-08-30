import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/split_engine.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final month = state.thisMonth;
    final monthTotal = month.fold<int>(0, (a, e) => a + e.amountPaise);
    final byCat = SplitEngine.byCategory(month);
    final daily = SplitEngine.dailyTotals(state.expenses, 7);

    if (state.expenses.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.insights_outlined, size: 42, color: cs.outline),
          const SizedBox(height: 10),
          Text('Add expenses to see insights.',
              style: TextStyle(color: cs.outline)),
        ]),
      );
    }

    final sorted = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('This month',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(rupees(monthTotal),
                    style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w800)),
                Text('${month.length} expenses logged',
                    style: TextStyle(color: cs.outline, fontSize: 12.5)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Last 7 days',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 150,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (_, t, __) => CustomPaint(
                      painter: _BarChartPainter(
                        values: daily,
                        progress: t,
                        barColor: cs.primary,
                        gridColor: cs.outlineVariant,
                        labelColor: cs.outline,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Where the money went',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (_, t, __) => CustomPaint(
                          painter: _DonutPainter(
                            slices: sorted
                                .map((e) => MapEntry(
                                    ExpenseCategory.byId(e.key).color,
                                    e.value.toDouble()))
                                .toList(),
                            progress: t,
                            trackColor: cs.surfaceContainerHighest,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        children: sorted.take(5).map((e) {
                          final c = ExpenseCategory.byId(e.key);
                          final pct = monthTotal == 0
                              ? 0
                              : (e.value * 100 / monthTotal).round();
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    color: c.color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(c.label,
                                      style: const TextStyle(fontSize: 12.5),
                                      overflow: TextOverflow.ellipsis)),
                              Text('$pct%',
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700)),
                            ]),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Hand-drawn bar chart — no charting package. Bars grow with [progress]
/// so the whole chart animates in on first paint.
class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.values,
    required this.progress,
    required this.barColor,
    required this.gridColor,
    required this.labelColor,
  });

  final List<int> values;
  final double progress;
  final Color barColor;
  final Color gridColor;
  final Color labelColor;

  static const _days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const labelH = 20.0;
    final chartH = size.height - labelH;
    final maxV = values.reduce(math.max).toDouble();
    final scale = maxV <= 0 ? 0.0 : chartH / maxV;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = chartH - (chartH / 3) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final slot = size.width / values.length;
    final barW = math.min(26.0, slot * 0.5);
    final today = DateTime.now();

    for (var i = 0; i < values.length; i++) {
      final h = values[i] * scale * progress;
      final cx = slot * i + slot / 2;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - barW / 2, chartH - h, barW, h),
        topLeft: const Radius.circular(7),
        topRight: const Radius.circular(7),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [barColor, barColor.withValues(alpha: .45)],
          ).createShader(rect.outerRect),
      );

      final d = today.subtract(Duration(days: values.length - 1 - i));
      final tp = TextPainter(
        text: TextSpan(
          text: _days[d.weekday % 7],
          style: TextStyle(fontSize: 11, color: labelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, chartH + 5));
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.progress != progress || old.values != values;
}

/// Hand-drawn donut chart for category share.
class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.progress,
    required this.trackColor,
  });

  final List<MapEntry<Color, double>> slices;
  final double progress;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (a, b) => a + b.value);
    final rect = Rect.fromLTWH(9, 9, size.width - 18, size.height - 18);
    const stroke = 18.0;

    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = trackColor,
    );
    if (total <= 0) return;

    var start = -math.pi / 2;
    for (final s in slices) {
      final sweep = (s.value / total) * math.pi * 2 * progress;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = s.key,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress || old.slices != slices;
}
