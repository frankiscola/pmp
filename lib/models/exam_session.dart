import 'exam_settings.dart';

/// Una sessione d'esame live in aula: nasce quando il trainer preme
/// "Crea sessione" e vive finché non viene chiusa.
class ExamSession {
  final String id;
  final String code; // es. "PMP-7823", mostrato via QR agli studenti
  final String trainerId;
  final String status; // lobby | running | paused | finished
  final int currentQuestionIndex;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final List<String> questionIds;
  final ExamSettings settings;

  /// Id del [Group] con cui questa sessione è stata fatta (null se lanciata
  /// senza gruppo). Permette di ricostruire, a sessione conclusa, in quale
  /// gruppo/giorno la sessione rientra — usato per il grafico di andamento
  /// del gruppo nel tempo e per la selezione adattiva delle domande.
  final String? groupId;

  /// True quando il trainer ha premuto "Rivela risposta" per la domanda
  /// corrente — solo allora gli studenti vedono corretto/sbagliato e la
  /// spiegazione. Si resetta a false ad ogni cambio di domanda.
  final bool answerRevealed;

  /// Timestamp di inizio dell'attuale pausa (Break), null se non in pausa.
  /// Usato insieme a [pausedSecondsTotal] per "congelare" correttamente il
  /// timer totale dell'esame durante il Break.
  final DateTime? pausedAt;

  /// Somma dei secondi trascorsi in TUTTE le pause precedenti (già concluse)
  /// di questa sessione. Non include la pausa in corso, che è tracciata da
  /// [pausedAt]. Si aggiorna ogni volta che il trainer riprende l'esame.
  final int pausedSecondsTotal;

  const ExamSession({
    required this.id,
    required this.code,
    required this.trainerId,
    required this.status,
    required this.currentQuestionIndex,
    required this.questionIds,
    required this.settings,
    this.answerRevealed = false,
    this.startedAt,
    this.finishedAt,
    this.pausedAt,
    this.pausedSecondsTotal = 0,
    this.groupId,
  });

  factory ExamSession.fromJson(Map<String, dynamic> json) {
    return ExamSession(
      id: json['id'] as String,
      code: json['code'] as String,
      trainerId: json['trainer_id'] as String,
      status: json['status'] as String,
      currentQuestionIndex: json['current_question_index'] as int? ?? 0,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      finishedAt: json['finished_at'] != null
          ? DateTime.parse(json['finished_at'] as String)
          : null,
      questionIds: List<String>.from(json['question_ids'] as List? ?? []),
      settings: json['settings'] != null
          ? ExamSettings.fromJson(
              Map<String, dynamic>.from(json['settings'] as Map),
            )
          : const ExamSettings(),
      answerRevealed: json['answer_revealed'] as bool? ?? false,
      pausedAt: json['paused_at'] != null
          ? DateTime.parse(json['paused_at'] as String)
          : null,
      pausedSecondsTotal: json['paused_seconds_total'] as int? ?? 0,
      groupId: json['group_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'trainer_id': trainerId,
      'status': status,
      'current_question_index': currentQuestionIndex,
      'started_at': startedAt?.toIso8601String(),
      'finished_at': finishedAt?.toIso8601String(),
      'question_ids': questionIds,
      'settings': settings.toJson(),
      'answer_revealed': answerRevealed,
      'paused_at': pausedAt?.toIso8601String(),
      'paused_seconds_total': pausedSecondsTotal,
      'group_id': groupId,
    };
  }

  /// Secondi rimanenti del timer "intero esame" (timerMode == total).
  /// Se la sessione non è ancora partita (startedAt nullo, non dovrebbe
  /// succedere dopo il fix di startSession, ma per sicurezza) restituisce
  /// il tempo pieno invece di un countdown già scaduto.
  ///
  /// Tiene conto delle pause (Break): il tempo trascorso durante un Break
  /// non deve "consumare" il timer. Se la sessione è IN PAUSA in questo
  /// momento, il calcolo si ferma a [pausedAt] invece di usare l'orario
  /// attuale, così il countdown resta congelato finché il trainer non
  /// riprende l'esame.
  int totalExamRemainingSeconds() {
    final totalSeconds = settings.totalExamMinutes * 60;
    if (startedAt == null) return totalSeconds;
    final effectiveNow = pausedAt ?? DateTime.now();
    final rawElapsed = effectiveNow.difference(startedAt!).inSeconds;
    final elapsed = rawElapsed - pausedSecondsTotal;
    final remaining = totalSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  ExamSession copyWith({
    String? status,
    int? currentQuestionIndex,
    DateTime? startedAt,
    DateTime? finishedAt,
    bool? answerRevealed,
    DateTime? pausedAt,
    int? pausedSecondsTotal,
  }) {
    return ExamSession(
      id: id,
      code: code,
      trainerId: trainerId,
      status: status ?? this.status,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      questionIds: questionIds,
      settings: settings,
      answerRevealed: answerRevealed ?? this.answerRevealed,
      pausedAt: pausedAt ?? this.pausedAt,
      pausedSecondsTotal: pausedSecondsTotal ?? this.pausedSecondsTotal,
      groupId: groupId,
    );
  }
}
