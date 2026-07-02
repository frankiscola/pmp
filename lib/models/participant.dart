/// Uno studente connesso a una sessione d'esame dal proprio smartphone.
class Participant {
  final String id;
  final String sessionId;
  final String name;
  final DateTime joinedAt;
  final int score;
  final Map<String, int> domainScores; // {"people": 15, "process": 20, ...}

  const Participant({
    required this.id,
    required this.sessionId,
    required this.name,
    required this.joinedAt,
    this.score = 0,
    this.domainScores = const {},
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      name: json['name'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      score: json['score'] as int? ?? 0,
      domainScores: json['domain_scores'] != null
          ? Map<String, int>.from(json['domain_scores'] as Map)
          : {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'name': name,
      'joined_at': joinedAt.toIso8601String(),
      'score': score,
      'domain_scores': domainScores,
    };
  }
}
