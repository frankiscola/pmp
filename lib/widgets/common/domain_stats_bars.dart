import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/analytics_service.dart';

/// Barre orizzontali con l'accuratezza per dominio (People / Process /
/// Business Environment), colorate coerentemente con [AppColors.domainColor].
/// Usato nel report personale dello studente, nella dashboard live del
/// trainer e nella schermata risultati finale — un unico widget per uno
/// stile sempre coerente.
class DomainStatsBars extends StatelessWidget {
  final Map<String, DomainStat> stats;

  /// Se true mostra anche "corretto/totale" oltre alla percentuale
  /// (utile nel report dettagliato, superfluo in spazi compatti).
  final bool showCounts;

  const DomainStatsBars({super.key, required this.stats, this.showCounts = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: AnalyticsService.domainOrder.map((domain) {
        final stat = stats[domain];
        final total = stat?.total ?? 0;
        final accuracy = stat?.accuracy ?? 0;
        final percent = (accuracy * 100).round();
        final color = AppColors.domainColor(domain);

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppConstants.domainLabels[domain] ?? domain,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (showCounts && total > 0)
                    Text(
                      '${stat!.correct}/$total  ',
                      style: AppTextStyles.caption,
                    ),
                  Text(
                    total == 0 ? '—' : '$percent%',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : accuracy,
                  minHeight: 10,
                  backgroundColor: AppColors.divider,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
