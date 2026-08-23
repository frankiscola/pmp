import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../models/answer.dart';
import '../../models/exam_session.dart';
import '../../models/participant.dart';
import '../../models/question.dart';
import '../../services/analytics_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/domain_stats_bars.dart';
import '../../widgets/common/leaderboard_list.dart';
import 'join_screen.dart';

/// Report personale di fine sessione dello studente: punteggio, il tuo
/// piazzamento in classifica, accuratezza per dominio ECO 2026 (non solo
/// il punteggio grezzo) e le domande sbagliate da rivedere.
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
  List<Participant> _allParticipants = [];
  List<Question> _myWrongQuestions = [];
  Map<String, DomainStat> _domainStats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      SupabaseService.instance.fetchParticipants(widget.session.id),
      SupabaseService.instance.fetchAllAnswers(widget.session.id),
      SupabaseService.instance.fetchQuestions(),
    ]);
    final participants = results[0] as List<Participant>;
    final allAnswers = results[1] as List<Answer>;
    final allQuestions = results[2] as List<Question>;

    final questionById = {for (final q in allQuestions) q.id: q};
    final sessionQuestions = widget.session.questionIds
        .map((id) => questionById[id])
        .whereType<Question>()
        .toList();
    final myAnswers = allAnswers
        .where((a) => a.participantId == widget.participant.id)
        .toList();
    final wrongQuestionIds = myAnswers
        .where((a) => !a.isCorrect)
        .map((a) => a.questionId)
        .toSet();

    if (!mounted) return;
    setState(() {
      _allParticipants = participants;
      _finalParticipant = participants.firstWhere(
        (p) => p.id == widget.participant.id,
        orElse: () => widget.participant,
      );
      _domainStats = AnalyticsService.domainStats(sessionQuestions, myAnswers);
      _myWrongQuestions = sessionQuestions
          .where((q) => wrongQuestionIds.contains(q.id))
          .toList();
      _loading = false;
    });
  }

  int? get _rank {
    final id = _finalParticipant?.id;
    if (id == null || _allParticipants.isEmpty) return null;
    final index = _allParticipants.indexWhere((p) => p.id == id);
    return index == -1 ? null : index + 1;
  }

  @override
  Widget build(BuildContext context) {
    final participant = _finalParticipant;
    final total = widget.session.questionIds.length;
    final rank = _rank;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Center(
          child: _loading || participant == null
              ? const CircularProgressIndicator(color: AppColors.pmiGreen)
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
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
                        if (rank != null && _allParticipants.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Sei arrivato ${rank}º su ${_allParticipants.length}',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),

                        // --- Accuratezza per dominio ---
                        AppCard(
                          backgroundColor: AppColors.surface,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Per dominio',
                                style: AppTextStyles.titleMedium,
                              ),
                              const SizedBox(height: 16),
                              DomainStatsBars(stats: _domainStats),
                            ],
                          ),
                        ),

                        // --- Da ripassare ---
                        if (_myWrongQuestions.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          AppCard(
                            backgroundColor: AppColors.surface,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Da ripassare',
                                  style: AppTextStyles.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_myWrongQuestions.length} domande sbagliate — tocca per rivederle con la spiegazione.',
                                  style: AppTextStyles.caption,
                                ),
                                const SizedBox(height: 12),
                                _ReviewList(questions: _myWrongQuestions),
                              ],
                            ),
                          ),
                        ],

                        // --- Mini classifica ---
                        if (_allParticipants.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          AppCard(
                            backgroundColor: AppColors.surface,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Classifica',
                                  style: AppTextStyles.titleMedium,
                                ),
                                const SizedBox(height: 12),
                                LeaderboardList(
                                  participants: _allParticipants,
                                  highlightParticipantId: participant.id,
                                  maxItems: 5,
                                  dense: true,
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 28),
                        AppButton(
                          label: 'Nuovo quiz',
                          fullWidth: true,
                          onPressed: () =>
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const JoinScreen(),
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

/// Elenco compatto delle domande sbagliate dallo studente, tappabili per
/// rivedere testo completo e spiegazione — pensato per il ripasso subito
/// dopo l'esame, mentre l'errore è ancora fresco in mente.
class _ReviewList extends StatelessWidget {
  final List<Question> questions;

  const _ReviewList({required this.questions});

  void _showDetail(BuildContext context, Question question) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.domainColor(
              question.domain,
            ).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Text(
            question.topic,
            style: AppTextStyles.label.copyWith(
              color: AppColors.domainColor(question.domain),
            ),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(question.questionText, style: AppTextStyles.bodyLarge),
              if (question.explanation.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Spiegazione', style: AppTextStyles.label),
                const SizedBox(height: 6),
                Text(question.explanation, style: AppTextStyles.bodyMedium),
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
    return Column(
      children: questions.map((q) {
        final color = AppColors.domainColor(q.domain);
        final text = q.questionText;
        final truncated = text.length > 90
            ? '${text.substring(0, 90)}…'
            : text;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            child: InkWell(
              onTap: () => _showDetail(context, q),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        truncated,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
