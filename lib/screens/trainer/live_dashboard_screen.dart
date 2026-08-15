import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../models/answer.dart';
import '../../models/exam_session.dart';
import '../../models/question.dart';
import '../../services/realtime_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/timer_widget.dart';
import 'results_screen.dart';

/// Dashboard live del trainer: mostra la domanda corrente, quanti hanno
/// risposto, la DISTRIBUZIONE delle risposte per opzione (non solo un
/// generico corretto/sbagliato), e i controlli per rivelare la risposta
/// e avanzare alla prossima domanda.
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
            actions: [
              if (session.settings.timerMode == AppConstants.timerPerQuestion)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: TimerWidget(
                      key: ValueKey('trainer_timer_$index'),
                      totalSeconds: session.settings.timerSecondsPerQuestion,
                      onExpired: () {},
                      compact: true,
                      paused: session.status == AppConstants.sessionPaused,
                    ),
                  ),
                ),
              if (session.settings.timerMode == AppConstants.timerTotal)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: TimerWidget(
                      key: const ValueKey('trainer_total_exam_timer'),
                      totalSeconds: session.totalExamRemainingSeconds(),
                      onExpired: () {},
                      compact: true,
                      paused: session.status == AppConstants.sessionPaused,
                      liveSync: true,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  tooltip: session.status == AppConstants.sessionPaused
                      ? 'Riprendi esame'
                      : 'Metti in pausa (Break)',
                  icon: Icon(
                    session.status == AppConstants.sessionPaused
                        ? Icons.play_circle_outline
                        : Icons.pause_circle_outline,
                    color: session.status == AppConstants.sessionPaused
                        ? AppColors.pmiGreen
                        : AppColors.textSecondary,
                  ),
                  onPressed: () async {
                    if (session.status == AppConstants.sessionPaused) {
                      await SupabaseService.instance.resumeSession(session);
                    } else {
                      await SupabaseService.instance.pauseSession(
                        widget.session.id,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (session.status == AppConstants.sessionPaused)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warningBg,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                        border: Border.all(color: AppColors.warning),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.pause_circle_filled,
                            color: AppColors.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Esame in pausa: gli studenti vedono la schermata di Break e il timer è congelato.',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Chip(
                        label: Text(question.topic),
                        backgroundColor: AppColors.domainColor(
                          question.domain,
                        ).withValues(alpha: 0.12),
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
                              child: answers.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'In attesa delle prime risposte...',
                                      ),
                                    )
                                  : SingleChildScrollView(
                                      child: _AnswerDistribution(
                                        question: question,
                                        answers: answers,
                                        revealed: session.answerRevealed,
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
                if (!session.answerRevealed)
                  AppButton(
                    label: 'Rivela risposta',
                    icon: Icons.visibility,
                    variant: AppButtonVariant.secondary,
                    fullWidth: true,
                    onPressed: session.status == AppConstants.sessionPaused
                        ? null
                        : () async {
                            try {
                              await SupabaseService.instance.revealAnswer(
                                widget.session.id,
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Errore nel rivelare la risposta: $e',
                                  ),
                                ),
                              );
                            }
                          },
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.successBg,
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                      border: Border.all(color: AppColors.success),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.success,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Risposta rivelata agli studenti',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                AppButton(
                  label: index + 1 >= _questions.length
                      ? 'Termina esame'
                      : 'Prossima domanda',
                  icon: Icons.arrow_forward,
                  fullWidth: true,
                  onPressed: session.status == AppConstants.sessionPaused
                      ? null
                      : () => _nextQuestion(index),
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
      backgroundColor: color.withValues(alpha: 0.08),
      borderColor: color.withValues(alpha: 0.3),
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

/// Sostituisce la vecchia barra generica corretto/sbagliato con la
/// distribuzione REALE delle risposte per opzione — molto più utile per
/// un trainer: mostra a colpo d'occhio dove il gruppo si è diviso.
/// Prima del "Rivela risposta" le barre sono neutre (blu); dopo, l'opzione
/// corretta diventa verde e le altre restano grigie.
class _AnswerDistribution extends StatelessWidget {
  final Question question;
  final List<Answer> answers;
  final bool revealed;

  const _AnswerDistribution({
    required this.question,
    required this.answers,
    required this.revealed,
  });

  List<Map<String, dynamic>> get _options {
    final raw =
        question.options['options'] as List? ??
        (question.options['hotspots'] as List?)
            ?.map((h) => {'id': h['id'], 'text': h['label']})
            .toList();
    return List<Map<String, dynamic>>.from(raw ?? []);
  }

  Set<String> get _correctIds {
    final correct = question.correctAnswers;
    if (correct is List) return Set<String>.from(correct);
    return {};
  }

  /// Estrae l'id (o gli id) scelti da una singola risposta, indipendentemente
  /// dal fatto che sia una stringa singola (single choice) o una lista
  /// (multiple response).
  List<String> _idsFrom(dynamic givenAnswer) {
    if (givenAnswer is String) return [givenAnswer];
    if (givenAnswer is List) return List<String>.from(givenAnswer);
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;

    // Per i tipi con struttura non riducibile a "opzioni con id/testo"
    // (matching, pull-down, case scenario) mostriamo un messaggio semplice
    // invece di una distribuzione fuorviante.
    if (options.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'La distribuzione per opzione non è disponibile per questo tipo di domanda.',
          style: AppTextStyles.bodyMedium,
        ),
      );
    }

    final counts = <String, int>{for (final o in options) o['id'] as String: 0};
    for (final a in answers) {
      for (final id in _idsFrom(a.givenAnswer)) {
        if (counts.containsKey(id)) counts[id] = counts[id]! + 1;
      }
    }
    final totalAnswers = answers.length;
    final maxCount = counts.values.isEmpty
        ? 0
        : counts.values.reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: options.map((opt) {
          final id = opt['id'] as String;
          final text = opt['text'] as String;
          final count = counts[id] ?? 0;
          final fraction = maxCount == 0 ? 0.0 : count / maxCount;
          final percent = totalAnswers == 0
              ? 0
              : (count / totalAnswers * 100).round();

          Color barColor = AppColors.pmiBlue;
          if (revealed) {
            barColor = _correctIds.contains(id)
                ? AppColors.pmiGreen
                : AppColors.textTertiary;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        text,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: revealed && _correctIds.contains(id)
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (revealed && _correctIds.contains(id))
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(
                          Icons.check_circle,
                          size: 16,
                          color: AppColors.success,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      '$count ($percent%)',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: barColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 10,
                    backgroundColor: AppColors.divider,
                    valueColor: AlwaysStoppedAnimation(barColor),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
