import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/participant.dart';
import 'app_card.dart';

/// Classifica dei partecipanti — riutilizzata sia nella leaderboard live
/// (che lo studente apre durante l'esame, o il trainer proietta in aula)
/// sia nella schermata risultati finale del trainer.
///
/// Se [highlightParticipantId] è impostato, quella riga viene evidenziata
/// (usato lato studente per farsi individuare subito nella lista).
/// Se [maxItems] è impostato, mostra solo i primi N (usato per anteprime
/// compatte, es. dentro il report personale dello studente).
class LeaderboardList extends StatelessWidget {
  final List<Participant> participants;
  final String? highlightParticipantId;
  final int? maxItems;
  final bool dense;

  const LeaderboardList({
    super.key,
    required this.participants,
    this.highlightParticipantId,
    this.maxItems,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Nessun partecipante ancora in classifica.',
          style: AppTextStyles.bodyMedium,
        ),
      );
    }
    final shown = maxItems != null && participants.length > maxItems!
        ? participants.sublist(0, maxItems)
        : participants;

    return Column(
      children: [
        for (int i = 0; i < shown.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: dense ? 6 : 10),
            child: _LeaderboardRow(
              rank: i + 1,
              participant: shown[i],
              highlighted: shown[i].id == highlightParticipantId,
              dense: dense,
            ),
          ),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final Participant participant;
  final bool highlighted;
  final bool dense;

  const _LeaderboardRow({
    required this.rank,
    required this.participant,
    required this.highlighted,
    required this.dense,
  });

  Color get _medalColor {
    switch (rank) {
      case 1:
        return const Color(0xFFD4AF37);
      case 2:
        return const Color(0xFFA7A7AD);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return AppColors.textTertiary;
    }
  }

  IconData? get _medalIcon => rank <= 3 ? Icons.emoji_events : null;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: dense ? 10 : 16,
      ),
      backgroundColor: highlighted ? AppColors.pmiGreenLight : null,
      borderColor: highlighted ? AppColors.pmiGreen : null,
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: _medalIcon != null
                ? Icon(_medalIcon, size: 20, color: _medalColor)
                : Text(
                    '$rank',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: _medalColor,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              participant.name,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: highlighted ? FontWeight.w700 : FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (highlighted)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text('Tu', style: AppTextStyles.caption),
            ),
          Text(
            '${participant.score} pt',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.pmiGreen,
            ),
          ),
        ],
      ),
    );
  }
}
