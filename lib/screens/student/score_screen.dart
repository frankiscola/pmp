import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/exam_session.dart';
import '../../models/participant.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../entry_screen.dart';

/// Schermata finale dello studente: punteggio totale e suddivisione
/// per dominio (People / Process / Business Environment).
class ScoreScreen extends StatefulWidget {
  final ExamSession session;
  final Participant participant;

  const ScoreScreen({
    super.key,
    required this.session,
    required this.participant,
  });

  @override
  State<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends State<ScoreScreen> {
  Participant? _finalParticipant;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final participants = await SupabaseService.instance.fetchParticipants(
      widget.session.id,
    );
    setState(() {
      _finalParticipant = participants.firstWhere(
        (p) => p.id == widget.participant.id,
        orElse: () => widget.participant,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final participant = _finalParticipant;
    final total = widget.session.questionIds.length;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Center(
          child: participant == null
              ? const CircularProgressIndicator(color: AppColors.pmiGreen)
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.emoji_events,
                          size: 56,
                          color: AppColors.pmiGreen,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Esame completato!',
                          style: AppTextStyles.titleLarge.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '${participant.score} / $total',
                          style: AppTextStyles.numericHero.copyWith(
                            color: AppColors.pmiGreen,
                          ),
                        ),
                        const SizedBox(height: 32),
                        AppCard(
                          backgroundColor: AppColors.surface,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Per dominio', style: AppTextStyles.label),
                              const SizedBox(height: 12),
                              ...participant.domainScores.entries.map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: AppColors.domainColor(e.key),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          AppConstants.domainLabels[e.key] ??
                                              e.key,
                                        ),
                                      ),
                                      Text(
                                        '${e.value}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        AppButton(
                          label: 'Torna alla home',
                          fullWidth: true,
                          onPressed: () =>
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const EntryScreen(),
                                ),
                                (route) => false,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
