import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../services/analytics_service.dart';

/// Elenco ordinato delle domande più sbagliate, con badge dominio/topic e
/// % di errore. Ogni riga è tappabile e apre testo completo + spiegazione —
/// il materiale pronto per il debrief in aula subito dopo una sessione.
class MostMissedList extends StatelessWidget {
  final List<QuestionMissStat> stats;

  const MostMissedList({super.key, required this.stats});

  void _showDetail(BuildContext context, QuestionMissStat stat) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.domainColor(
                  stat.question.domain,
                ).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Text(
                stat.question.topic,
                style: AppTextStyles.label.copyWith(
                  color: AppColors.domainColor(stat.question.domain),
                ),
              ),
            ),
            const Spacer(),
            Text(
              '${stat.wrong}/${stat.total} sbagliata',
              style: AppTextStyles.caption,
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(stat.question.questionText, style: AppTextStyles.bodyLarge),
              if (stat.question.explanation.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Spiegazione', style: AppTextStyles.label),
                const SizedBox(height: 6),
                Text(
                  stat.question.explanation,
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Nessun errore registrato — ottimo lavoro del gruppo!',
          style: AppTextStyles.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < stats.length; i++)
          _MostMissedRow(
            rank: i + 1,
            stat: stats[i],
            onTap: () => _showDetail(context, stats[i]),
          ),
      ],
    );
  }
}

class _MostMissedRow extends StatelessWidget {
  final int rank;
  final QuestionMissStat stat;
  final VoidCallback onTap;

  const _MostMissedRow({
    required this.rank,
    required this.stat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (stat.missRate * 100).round();
    final color = AppColors.domainColor(stat.question.domain);
    final text = stat.question.questionText;
    final truncated = text.length > 100 ? '${text.substring(0, 100)}…' : text;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '$rank',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      truncated,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            AppConstants.domainLabels[stat.question.domain] ??
                                stat.question.topic,
                            style: AppTextStyles.caption.copyWith(color: color),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$percent%',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
