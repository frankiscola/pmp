import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/exam_session.dart';
import '../../models/participant.dart';
import '../../models/question.dart';
import '../../services/realtime_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/timer_widget.dart';
import '../../widgets/common/question_type_router.dart';
import 'score_screen.dart';

/// Schermata principale dello studente durante l'esame: mostra la
/// domanda corrente (sincronizzata via realtime con il trainer),
/// raccoglie la risposta e mostra il feedback se la modalità lo prevede.
///
/// Gestisce anche il caso in cui il trainer torni indietro a una domanda
/// già risposta ("revisit"): quella domanda si BLOCCA — lo studente vede
/// la risposta data in precedenza ma non può più modificarla.
class QuestionScreen extends StatefulWidget {
  final ExamSession session;
  final Participant participant;

  const QuestionScreen({super.key, required this.session, required this.participant});

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  List<Question> _questions = [];
  bool _loading = true;

  final Set<int> _answeredIndices = {};
  /// Cache locale delle risposte già date, per ripristinarle quando il
  /// trainer torna su una domanda già risposta (revisit).
  final Map<int, dynamic> _submittedAnswers = {};
  /// Indice più avanti raggiunto finora in questa sessione: se l'indice
  /// corrente scende sotto questo valore, siamo in un revisit.
  int _maxIndexReached = -1;

  dynamic _currentAnswer;
  DateTime? _questionStartedAt;

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
      _questionStartedAt = DateTime.now();
    });
  }

  Future<void> _submit(int index) async {
    if (_currentAnswer == null) return;
    _answeredIndices.add(index);
    _submittedAnswers[index] = _currentAnswer;
    final timeSpent = _questionStartedAt != null
        ? DateTime.now().difference(_questionStartedAt!).inSeconds
        : 0;
    await SupabaseService.instance.submitAnswer(
      sessionId: widget.session.id,
      participantId: widget.participant.id,
      question: _questions[index],
      givenAnswer: _currentAnswer,
      timeSpentSeconds: timeSpent,
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
      builder: (context, snapshot) {
        final session = snapshot.data ?? widget.session;

        if (session.status == AppConstants.sessionFinished) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ScoreScreen(session: session, participant: widget.participant),
              ),
            );
          });
        }

        final index = session.currentQuestionIndex;
        if (index >= _questions.length) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Un "revisit" è quando il trainer torna a una domanda con indice
        // più basso del punto più avanti già raggiunto: in quel caso la
        // domanda va bloccata, non più editabile.
        final isRevisit = index < _maxIndexReached;
        if (index > _maxIndexReached) _maxIndexReached = index;

        final question = _questions[index];
        final feedbackEnabled = session.settings.feedbackMode == AppConstants.feedbackImmediate;
        final alreadyAnswered = _answeredIndices.contains(index);
        // Il reveal (colori corretto/sbagliato + spiegazione) appare solo se
        // la modalità prevede feedback immediato E il trainer ha premuto
        // "Rivela risposta" per questa domanda.
        final revealed = feedbackEnabled && session.answerRevealed;
        final locked = isRevisit && alreadyAnswered;

        // Su revisit, ripristina la risposta data in precedenza come
        // "corrente", così se il trainer rivela in quel momento tutto torna
        // coerente.
        if (locked && _submittedAnswers.containsKey(index)) {
          _currentAnswer = _submittedAnswers[index];
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text('Domanda ${index + 1} / ${_questions.length}'),
            backgroundColor: AppColors.surface,
            actions: [
              if (session.settings.timerMode == AppConstants.timerPerQuestion && !locked)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: TimerWidget(
                      key: ValueKey('timer_$index'),
                      totalSeconds: session.settings.timerSecondsPerQuestion,
                      onExpired: () => _submit(index),
                      compact: true,
                    ),
                  ),
                ),
              if (session.settings.timerMode == AppConstants.timerTotal)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: TimerWidget(
                      key: const ValueKey('total_exam_timer'),
                      totalSeconds: _totalExamRemainingSeconds(session),
                      onExpired: () {},
                      compact: true,
                    ),
                  ),
                ),
            ],
          ),
          body: SingleChildScrollView(
            key: ValueKey('question_$index'),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (locked)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.history, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Il trainer è tornato su una domanda precedente — la tua risposta resta quella già data.',
                            style: AppTextStyles.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                LinearProgressIndicator(
                  value: (index + 1) / _questions.length,
                  backgroundColor: AppColors.divider,
                  valueColor: const AlwaysStoppedAnimation(AppColors.pmiGreen),
                ),
                const SizedBox(height: 20),
                AppCard(
                  child: Text(question.questionText, style: AppTextStyles.question),
                ),
                const SizedBox(height: 20),
                QuestionTypeRouter(
                  key: ValueKey('router_$index'),
                  question: question,
                  revealed: revealed,
                  locked: locked,
                  initialAnswer: _submittedAnswers[index],
                  onAnswered: (answer) {
                    _currentAnswer = answer;
                    _submit(index);
                    setState(() {});
                  },
                ),
                if (alreadyAnswered && !revealed && !locked) ...[
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      feedbackEnabled
                          ? 'Risposta inviata — puoi ancora cambiarla finché il trainer non rivela la risposta corretta.'
                          : 'Risposta inviata! Vedrai il punteggio a fine esame.',
                      style: AppTextStyles.caption,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                if (revealed) ...[
                  const SizedBox(height: 20),
                  AppCard(
                    backgroundColor: AppColors.infoBg,
                    borderColor: AppColors.pmiBlue,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Spiegazione', style: AppTextStyles.label.copyWith(color: AppColors.pmiBlue)),
                        const SizedBox(height: 6),
                        Text(question.explanation, style: AppTextStyles.bodyLarge),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'In attesa che il trainer passi alla prossima domanda...',
                      style: AppTextStyles.caption,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  int _totalExamRemainingSeconds(ExamSession session) {
    final totalSeconds = session.settings.totalExamMinutes * 60;
    if (session.startedAt == null) return totalSeconds;
    final elapsed = DateTime.now().difference(session.startedAt!).inSeconds;
    final remaining = totalSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }
}
