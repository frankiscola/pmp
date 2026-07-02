import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/answer.dart';
import '../../models/exam_session.dart';
import '../../models/question.dart';
import '../../services/realtime_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import 'results_screen.dart';

/// Dashboard live del trainer: mostra la domanda corrente, quanti
/// hanno risposto e la distribuzione delle risposte in tempo reale,
/// con il controllo per avanzare manualmente alla prossima domanda.
class LiveDashboardScreen extends StatefulWidget {
  final ExamSession session;

  const LiveDashboardScreen({super.key, required this.session});

  @override
  State<LiveDashboardScreen> createState() => _LiveDashboardScreenState();
}

class _LiveDashboardScreenState extends State<LiveDashboardScreen> {
  List<Question> _questions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final all = await SupabaseService.instance.fetchQuestions();
    final byId = {for (final q in all) q.id: q};
    setState(() {
      _questions = widget.session.questionIds
          .map((id) => byId[id])
          .whereType<Question>()
          .toList();
      _loading = false;
    });
  }

  Future<void> _nextQuestion(int currentIndex) async {
    final nextIndex = currentIndex + 1;
    if (nextIndex >= _questions.length) {
      await SupabaseService.instance.finishSession(widget.session.id);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultsScreen(session: widget.session),
        ),
      );
      return;
    }
    await SupabaseService.instance.goToQuestionIndex(
      widget.session.id,
      nextIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<ExamSession?>(
      stream: RealtimeService.instance.watchSession(widget.session.id),
      initialData: widget.session,
      builder: (context, sessionSnap) {
        final session = sessionSnap.data ?? widget.session;
        final index = session.currentQuestionIndex;
        if (index >= _questions.length) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final question = _questions[index];

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text('Domanda ${index + 1} / ${_questions.length}'),
            backgroundColor: AppColors.surface,
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Chip(
                        label: Text(question.topic),
                        backgroundColor: AppColors.domainColor(
                          question.domain,
                        ).withValues(alpha:0.12),
                        labelStyle: TextStyle(
                          color: AppColors.domainColor(question.domain),
                        ),
                        side: BorderSide.none,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        question.questionText,
                        style: AppTextStyles.question,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: StreamBuilder<List<Answer>>(
                    stream: RealtimeService.instance.watchAnswers(
                      widget.session.id,
                    ),
                    builder: (context, answerSnap) {
                      final answers = (answerSnap.data ?? [])
                          .where((a) => a.questionId == question.id)
                          .toList();
                      final correctCount = answers
                          .where((a) => a.isCorrect)
                          .length;
                      final total = answers.length;

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _StatBox(
                                  label: 'Hanno risposto',
                                  value: '$total',
                                  color: AppColors.pmiBlue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatBox(
                                  label: 'Risposte corrette',
                                  value: total == 0
                                      ? '—'
                                      : '$correctCount / $total',
                                  color: AppColors.pmiGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: AppCard(
                              child: total == 0
                                  ? const Center(
                                      child: Text(
                                        'In attesa delle prime risposte...',
                                      ),
                                    )
                                  : Center(
                                      child: LinearProgressIndicator(
                                        value: total == 0
                                            ? 0
                                            : correctCount / total,
                                        minHeight: 24,
                                        backgroundColor: AppColors.errorBg,
                                        valueColor:
                                            const AlwaysStoppedAnimation(
                                              AppColors.pmiGreen,
                                            ),
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                AppButton(
                  label: index + 1 >= _questions.length
                      ? 'Termina esame'
                      : 'Prossima domanda',
                  icon: Icons.arrow_forward,
                  fullWidth: true,
                  onPressed: () => _nextQuestion(index),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: color.withValues(alpha:0.08),
      borderColor: color.withValues(alpha:0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.label),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.titleLarge.copyWith(color: color)),
        ],
      ),
    );
  }
}
