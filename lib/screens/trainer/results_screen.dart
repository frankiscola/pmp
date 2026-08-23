import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/answer.dart';
import '../../models/exam_session.dart';
import '../../models/group.dart';
import '../../models/participant.dart';
import '../../models/question.dart';
import '../../services/analytics_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/domain_stats_bars.dart';
import '../../widgets/common/group_trend_chart.dart';
import '../../widgets/common/leaderboard_list.dart';
import '../../widgets/common/most_missed_list.dart';
import 'trainer_home_screen.dart';

/// Classifica e analisi finale al termine della sessione: punteggio per
/// studente, accuratezza per dominio ECO 2026, le domande più sbagliate
/// (materiale pronto per il debrief) e — se la sessione è collegata a un
/// [Group] — l'andamento del gruppo sessione dopo sessione nel tempo.
class ResultsScreen extends StatefulWidget {
  final ExamSession session;

  const ResultsScreen({super.key, required this.session});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  List<Participant> _participants = [];
  Map<String, DomainStat> _domainStats = {};
  List<QuestionMissStat> _mostMissed = [];
  Group? _group;
  List<GroupSessionSnapshot> _groupTrend = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final groupId = widget.session.groupId;
    final results = await Future.wait([
      SupabaseService.instance.fetchParticipants(widget.session.id),
      SupabaseService.instance.fetchAllAnswers(widget.session.id),
      SupabaseService.instance.fetchQuestions(),
      groupId != null
          ? SupabaseService.instance.fetchGroupById(groupId)
          : Future<Group?>.value(null),
      groupId != null
          ? SupabaseService.instance.fetchGroupSessionTrend(groupId)
          : Future<List<GroupSessionSnapshot>>.value(const []),
    ]);

    final participants = results[0] as List<Participant>;
    final answers = results[1] as List<Answer>;
    final allQuestions = results[2] as List<Question>;
    final group = results[3] as Group?;
    final trend = results[4] as List<GroupSessionSnapshot>;

    final questionById = {for (final q in allQuestions) q.id: q};
    final sessionQuestions = widget.session.questionIds
        .map((id) => questionById[id])
        .whereType<Question>()
        .toList();

    if (!mounted) return;
    setState(() {
      _participants = participants;
      _domainStats = AnalyticsService.domainStats(sessionQuestions, answers);
      _mostMissed = AnalyticsService.mostMissed(
        sessionQuestions,
        answers,
        limit: 10,
      );
      _group = group;
      _groupTrend = trend;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Risultati finali')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (_group != null) ...[
                      AppCard(
                        backgroundColor: AppColors.pmiGreenLight,
                        child: Row(
                          children: [
                            const Icon(Icons.groups, color: AppColors.pmiGreen),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _group!.name,
                                style: AppTextStyles.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    const Text('Classifica', style: AppTextStyles.titleLarge),
                    const SizedBox(height: 16),
                    LeaderboardList(participants: _participants),
                    const SizedBox(height: 24),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Andamento per dominio (questa sessione)',
                            style: AppTextStyles.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          DomainStatsBars(stats: _domainStats),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Domande più sbagliate',
                            style: AppTextStyles.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Materiale pronto per il debrief — tocca una '
                            'riga per rivederla con la spiegazione.',
                            style: AppTextStyles.caption,
                          ),
                          const SizedBox(height: 12),
                          MostMissedList(stats: _mostMissed),
                        ],
                      ),
                    ),
                    if (_group != null) ...[
                      const SizedBox(height: 16),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Andamento di "${_group!.name}" nel tempo',
                              style: AppTextStyles.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Una colonna per ogni sessione conclusa con '
                              'questo gruppo — utile per vedere se il ritmo '
                              'del corso sta funzionando.',
                              style: AppTextStyles.caption,
                            ),
                            const SizedBox(height: 16),
                            GroupTrendChart(snapshots: _groupTrend),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Nuova sessione',
                      fullWidth: true,
                      variant: AppButtonVariant.outline,
                      onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => TrainerHomeScreen(group: _group),
                        ),
                        (route) => false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
