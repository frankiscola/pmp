/// Un "gruppo" rappresenta una classe/coorte di studenti che il trainer
/// incontra per più giornate consecutive (es. 4-8 giorni di corso).
///
/// Serve a tenere traccia di quali domande sono già state proposte a quel
/// gruppo, così le sessioni successive possono escluderle ed evitare
/// ripetizioni. Lo storico vive lato database (colonna `used_question_ids`)
/// così è condiviso tra dispositivi/sessioni del browser del trainer.
class Group {
  final String id;
  final String trainerId;
  final String name;
  final List<String> usedQuestionIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Group({
    required this.id,
    required this.trainerId,
    required this.name,
    required this.usedQuestionIds,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      trainerId: json['trainer_id'] as String,
      name: json['name'] as String,
      usedQuestionIds: List<String>.from(
        json['used_question_ids'] as List? ?? [],
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.parse(json['created_at'] as String),
    );
  }

  Group copyWith({List<String>? usedQuestionIds}) {
    return Group(
      id: id,
      trainerId: trainerId,
      name: name,
      usedQuestionIds: usedQuestionIds ?? this.usedQuestionIds,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
