import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/analytics_service.dart';

/// Mini grafico a barre: per ogni sessione (giornata) conclusa con un
/// gruppo, mostra l'accuratezza raggiunta in ciascun dominio ECO 2026.
/// Nessuna dipendenza da pacchetti di charting esterni — solo widget
/// Flutter nativi, così non serve toccare pubspec.yaml.
class GroupTrendChart extends StatelessWidget {
  final List<GroupSessionSnapshot> snapshots;
  static const double _maxBarHeight = 90;
  static const double _barWidth = 10;

  const GroupTrendChart({super.key, required this.snapshots});

  String _dayLabel(DateTime d) {
    const months = [
      '',
      'gen',
      'feb',
      'mar',
      'apr',
      'mag',
      'giu',
      'lug',
      'ago',
      'set',
      'ott',
      'nov',
      'dic',
    ];
    return '${d.day} ${months[d.month]}';
  }

  @override
  Widget build(BuildContext context) {
    if (snapshots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Ancora nessuna sessione conclusa con questo gruppo: il grafico '
          'comparirà da qui in avanti, sessione dopo sessione.',
          style: AppTextStyles.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _maxBarHeight + 40,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final snap in snapshots)
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: _DayColumn(
                      label: _dayLabel(snap.date),
                      stats: snap.domainStats,
                      maxHeight: _maxBarHeight,
                      barWidth: _barWidth,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          children: AnalyticsService.domainOrder.map((domain) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.domainColor(domain),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  AppConstants.domainLabels[domain] ?? domain,
                  style: AppTextStyles.caption,
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  final String label;
  final Map<String, DomainStat> stats;
  final double maxHeight;
  final double barWidth;

  const _DayColumn({
    required this.label,
    required this.stats,
    required this.maxHeight,
    required this.barWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: AnalyticsService.domainOrder.map((domain) {
            final stat = stats[domain];
            final accuracy = stat?.accuracy ?? 0;
            final height = (accuracy * maxHeight).clamp(3, maxHeight);
            final color = AppColors.domainColor(domain);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Tooltip(
                message: stat == null || stat.total == 0
                    ? 'Nessun dato'
                    : '${AppConstants.domainLabels[domain]}: '
                          '${(accuracy * 100).round()}% (${stat.correct}/${stat.total})',
                child: Container(
                  width: barWidth,
                  height: height.toDouble(),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}
