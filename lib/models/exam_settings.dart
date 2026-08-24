/// Impostazioni di una sessione d'esame — configurabili dal trainer
/// prima di lanciare il quiz, oppure direttamente dalla tabella
/// `exam_settings` su Supabase (due preset già pronti: Training / Simulazione).
class ExamSettings {
  final String feedbackMode; // immediate | end_of_exam
  final String timerMode; // per_question | total | none
  final int timerSecondsPerQuestion;
  final int totalExamMinutes;
  final bool showLeaderboard;
  final bool randomizeQuestions;
  final bool randomizeOptions;
  final String examMode; // training | simulation
  final int questionCount;

  /// A chi viene mostrata la spiegazione dopo il reveal: 'student' (solo
  /// studente, comportamento storico), 'trainer' (solo trainer, per non
  /// distrarre gli studenti durante la sessione), 'both'. Default 'student'
  /// per compatibilità con le sessioni create prima di questo campo.
  final String explanationVisibility;

  const ExamSettings({
    this.feedbackMode = 'immediate',
    this.timerMode = 'per_question',
    this.timerSecondsPerQuestion = 90,
    this.totalExamMinutes = 240,
    this.showLeaderboard = false,
    this.randomizeQuestions = true,
    this.randomizeOptions = true,
    this.examMode = 'training',
    this.questionCount = 20,
    this.explanationVisibility = 'student',
  });

  factory ExamSettings.fromJson(Map<String, dynamic> json) {
    return ExamSettings(
      feedbackMode: json['feedback_mode'] as String? ?? 'immediate',
      timerMode: json['timer_mode'] as String? ?? 'per_question',
      timerSecondsPerQuestion: json['timer_seconds_per_question'] as int? ?? 90,
      totalExamMinutes: json['total_exam_minutes'] as int? ?? 240,
      showLeaderboard: json['show_leaderboard'] as bool? ?? false,
      randomizeQuestions: json['randomize_questions'] as bool? ?? true,
      randomizeOptions: json['randomize_options'] as bool? ?? true,
      examMode: json['exam_mode'] as String? ?? 'training',
      questionCount: json['question_count'] as int? ?? 20,
      explanationVisibility:
          json['explanation_visibility'] as String? ?? 'student',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'feedback_mode': feedbackMode,
      'timer_mode': timerMode,
      'timer_seconds_per_question': timerSecondsPerQuestion,
      'total_exam_minutes': totalExamMinutes,
      'show_leaderboard': showLeaderboard,
      'randomize_questions': randomizeQuestions,
      'randomize_options': randomizeOptions,
      'exam_mode': examMode,
      'question_count': questionCount,
      'explanation_visibility': explanationVisibility,
    };
  }

  ExamSettings copyWith({
    String? feedbackMode,
    String? timerMode,
    int? timerSecondsPerQuestion,
    int? totalExamMinutes,
    bool? showLeaderboard,
    bool? randomizeQuestions,
    bool? randomizeOptions,
    String? examMode,
    int? questionCount,
    String? explanationVisibility,
  }) {
    return ExamSettings(
      feedbackMode: feedbackMode ?? this.feedbackMode,
      timerMode: timerMode ?? this.timerMode,
      timerSecondsPerQuestion: timerSecondsPerQuestion ?? this.timerSecondsPerQuestion,
      totalExamMinutes: totalExamMinutes ?? this.totalExamMinutes,
      showLeaderboard: showLeaderboard ?? this.showLeaderboard,
      randomizeQuestions: randomizeQuestions ?? this.randomizeQuestions,
      randomizeOptions: randomizeOptions ?? this.randomizeOptions,
      examMode: examMode ?? this.examMode,
      questionCount: questionCount ?? this.questionCount,
      explanationVisibility:
          explanationVisibility ?? this.explanationVisibility,
    );
  }
}
