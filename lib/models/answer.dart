/// La risposta data da un partecipante a una domanda.
class Answer {
  final String id;
  final String sessionId;
  final String participantId;
  final String questionId;
  final dynamic givenAnswer; // List<String> o Map<String,String> a seconda del tipo
  final bool isCorrect;
  final int timeSpentSeconds;
  final DateTime answeredAt;

  const Answer({
    required this.id,
    required this.sessionId,
    required this.participantId,
    required this.questionId,
    required this.givenAnswer,
    required this.isCorrect,
    required this.timeSpentSeconds,
    required this.answeredAt,
  });

  factory Answer.fromJson(Map<String, dynamic> json) {
    return Answer(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      participantId: json['participant_id'] as String,
      questionId: json['question_id'] as String,
      givenAnswer: json['given_answer'],
      isCorrect: json['is_correct'] as bool,
      timeSpentSeconds: json['time_spent_seconds'] as int? ?? 0,
      answeredAt: DateTime.parse(json['answered_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'participant_id': participantId,
      'question_id': questionId,
      'given_answer': givenAnswer,
      'is_correct': isCorrect,
      'time_spent_seconds': timeSpentSeconds,
      'answered_at': answeredAt.toIso8601String(),
    };
  }
}
