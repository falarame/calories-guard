import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class WeightChartCard extends StatelessWidget {
  const WeightChartCard({
    super.key,
    required this.weightLogs,
    required this.goalProgress,
    required this.targetWeight,
    this.showGoalDetails = true,
  });

  final List<Map<String, dynamic>> weightLogs;
  final Map<String, dynamic> goalProgress;
  final double targetWeight;
  final bool showGoalDetails;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;

    if (weightLogs.isEmpty) {
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.tr('progress.weight_chart'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: Column(children: [
                Icon(Icons.monitor_weight_outlined,
                    size: 48, color: palette.textFaint),
                const SizedBox(height: 8),
                Text(
                  l10n.tr('progress.no_data.title'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.tr('progress.no_data.body'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: palette.textSecondary),
                ),
              ]),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    }

    final spots = <FlSpot>[];
    double minW = double.infinity, maxW = 0;
    for (int i = 0; i < weightLogs.length; i++) {
      final w = (weightLogs[i]['weight'] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), w));
      if (w < minW) minW = w;
      if (w > maxW) maxW = w;
    }
    if (targetWeight > 0) {
      if (targetWeight < minW) minW = targetWeight;
      if (targetWeight > maxW) maxW = targetWeight;
    }
    minW = (minW - 2).floorToDouble();
    maxW = (maxW + 2).ceilToDouble();

    final step = (weightLogs.length / 5).ceil().clamp(1, 999);
    final showTarget = targetWeight > 0;

    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(
            l10n.tr('progress.weight_chart'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: palette.textPrimary,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: palette.brandSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              Icon(Icons.show_chart, size: 14, color: palette.brandStrong),
              const SizedBox(width: 4),
              Text(
                l10n.tr(
                    'progress.points_count', {'count': '${weightLogs.length}'}),
                style: TextStyle(
                  fontSize: 11,
                  color: palette.brandStrong,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minY: minW,
              maxY: maxW,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: palette.chartGrid, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (v, _) => Text(
                      '${v.toInt()}',
                      style: TextStyle(fontSize: 10, color: palette.textFaint),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: step.toDouble(),
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= weightLogs.length) {
                        return const SizedBox();
                      }
                      final raw = weightLogs[idx]['date'] as String;
                      try {
                        final dt = DateTime.parse(raw);
                        return Text(
                          '${dt.day}/${dt.month}',
                          style:
                              TextStyle(fontSize: 9, color: palette.textFaint),
                        );
                      } catch (_) {
                        return const SizedBox();
                      }
                    },
                  ),
                ),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: palette.brand,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
                      radius: 3,
                      color: palette.surfaceCard,
                      strokeWidth: 2,
                      strokeColor: palette.brand,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: palette.brand.withOpacity(0.08),
                  ),
                ),
                if (showTarget)
                  LineChartBarData(
                    spots: [
                      FlSpot(0, targetWeight),
                      FlSpot((spots.length - 1).toDouble(), targetWeight),
                    ],
                    isCurved: false,
                    color: palette.danger.withOpacity(0.55),
                    barWidth: 1.5,
                    dashArray: const [6, 4],
                    dotData: const FlDotData(show: false),
                  ),
                if (showTarget)
                  LineChartBarData(
                    spots: [
                      FlSpot((spots.length - 1).toDouble(), targetWeight),
                    ],
                    color: Colors.transparent,
                    barWidth: 0,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
                        radius: 6,
                        color: palette.danger,
                        strokeWidth: 2.5,
                        strokeColor: palette.surfaceCard,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _legendDot(palette.brand, l10n.tr('progress.legend.actual'), palette),
          const SizedBox(width: 12),
          _legendDot(
              palette.danger, l10n.tr('progress.legend.target'), palette),
        ]),
        if (showGoalDetails && goalProgress.isNotEmpty) ...[
          const SizedBox(height: 16),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          const SizedBox(height: 14),
          _GoalDetails(goalProgress: goalProgress),
        ],
      ]),
    );
  }

  Widget _legendDot(Color color, String label, AppPalette palette) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: palette.textPrimary.withOpacity(0.9),
        ),
      ),
    ]);
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 13),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }
}

class _GoalDetails extends StatelessWidget {
  const _GoalDetails({required this.goalProgress});
  final Map<String, dynamic> goalProgress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final palette = context.palette;

    final start = (goalProgress['start_weight'] as num?)?.toDouble();
    final curr = (goalProgress['current_weight'] as num?)?.toDouble();
    final target = (goalProgress['target_weight'] as num?)?.toDouble();
    final remKg = (goalProgress['remaining_kg'] as num?)?.toDouble();
    final estDays = goalProgress['estimated_days'] as int?;
    final targetDate = goalProgress['goal_target_date'] as String?;
    final kg = l10n.tr('unit.kg');

    String deadlineText = l10n.tr('progress.goal.no_deadline');
    if (targetDate != null) {
      try {
        final dt = DateTime.parse(targetDate);
        deadlineText = DateFormat('d MMM yyyy', locale).format(dt);
        final daysLeft = dt.difference(DateTime.now()).inDays;
        if (daysLeft >= 0) {
          deadlineText +=
              ' (${l10n.tr('progress.goal.in_days', {'days': '$daysLeft'})})';
        }
      } catch (_) {}
    }

    String estimateText = '—';
    if (estDays != null && estDays > 0) {
      if (estDays < 30) {
        estimateText =
            l10n.tr('progress.goal.in_about_days', {'days': '$estDays'});
      } else {
        final months = (estDays / 30).toStringAsFixed(1);
        estimateText =
            l10n.tr('progress.goal.in_about_months', {'months': months});
      }
    }

    return Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _weightChip(
            context,
            label: l10n.tr('progress.goal.start'),
            value: start != null ? '${start.toStringAsFixed(1)} $kg' : '—',
            color: palette.textSecondary,
          ),
          _weightChip(
            context,
            label: l10n.tr('progress.goal.current'),
            value: curr != null ? '${curr.toStringAsFixed(1)} $kg' : '—',
            color: palette.brand,
          ),
          _weightChip(
            context,
            label: l10n.tr('progress.goal.target'),
            value: target != null ? '${target.toStringAsFixed(1)} $kg' : '—',
            color: palette.brandStrong,
          ),
        ],
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: _infoChip(
            context,
            icon: Icons.flag_rounded,
            label: l10n.tr('progress.goal.deadline'),
            value: deadlineText,
            color: const Color(0xFF465396),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _infoChip(
            context,
            icon: Icons.timer_outlined,
            label: l10n.tr('progress.goal.estimate'),
            value: estimateText,
            color: palette.brand,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _infoChip(
            context,
            icon: Icons.monitor_weight_outlined,
            label: l10n.tr('progress.goal.remaining'),
            value: remKg != null ? '${remKg.toStringAsFixed(1)} $kg' : '—',
            color: palette.warning,
          ),
        ),
      ]),
    ]);
  }

  Widget _weightChip(BuildContext context,
      {required String label, required String value, required Color color}) {
    final palette = context.palette;
    return Column(children: [
      Text(value,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: 10, color: palette.textSecondary)),
    ]);
  }

  Widget _infoChip(BuildContext context,
      {required IconData icon,
      required String label,
      required String value,
      required Color color}) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(fontSize: 9, color: palette.textSecondary),
            textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}
