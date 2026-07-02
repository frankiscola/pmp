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

  const ExamSession({
    required this.id,
    required this.code,
    required this.trainerId,
    required this.status,
    required this.currentQuestionIndex,
    required this.questionIds,
    required this.settings,
    this.startedAt,
    this.finishedAt,
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
          ? ExamSettings.fromJson(Map<String, dynamic>.from(json['settings'] as Map))
          : const ExamSettings(),
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
    };
  }

  ExamSession copyWith({
    String? status,
    int? currentQuestionIndex,
    DateTime? startedAt,
    DateTime? finishedAt,
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
    );
  }
}
