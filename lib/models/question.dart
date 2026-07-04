/// Modello domanda — copre tutti i 7 tipi ECO 2026.
///
/// La struttura di `options` e `correctAnswers` cambia in base al `type`:
///
/// single_choice / multiple_response:
///   options: [{"id": "a", "text": "..."}]
///   correctAnswers: ["a"]  (una o più id)
///
/// matching (drag & drop, es. le 110 domande di David McLachlan):
///   options: {
///     "left": [{"id": "l1", "text": "Analogous"}, ...],
///     "right": [{"id": "r1", "text": "Il team usa dati da un progetto simile"}, ...]
///   }
///   correctAnswers: {"l1": "r1", "l2": "r2", ...}
///
/// pulldown:
///   options: {"blanks": [{"id": "b1", "choices": ["A","B","C"]}]}
///   correctAnswers: {"b1": "A"}
///
/// case_scenario:
///   options: {"scenario": "testo lungo...", "subQuestions": [ {...question...} ]}
///
/// hotspot / graphic_based:
///   options: {"imageDescription": "...", "hotspots": [{"id":"h1","x":0.4,"y":0.2,"label":"..."}]}
///   correctAnswers: ["h1"]
class Question {
  final String id;
  final String domain; // people | process | business_environment
  final String type; // vedi AppConstants.type*
  final String questionText;
  final Map<String, dynamic> options;
  final dynamic correctAnswers; // List<String> oppure Map<String,String>
  final String explanation;
  final String source;
  final String topic;
  final String difficulty; // easy | medium | hard
  final String approach; // predictive | agile | hybrid

  const Question({
    required this.id,
    required this.domain,
    required this.type,
    required this.questionText,
    required this.options,
    required this.correctAnswers,
    required this.explanation,
    required this.source,
    required this.topic,
    this.difficulty = 'medium',
    this.approach = 'predictive',
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      domain: json['domain'] as String,
      type: json['type'] as String,
      questionText: json['question_text'] as String,
      options: Map<String, dynamic>.from(json['options'] as Map),
      correctAnswers: json['correct_answers'],
      explanation: json['explanation'] as String? ?? '',
      source: json['source'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? 'medium',
      approach: json['approach'] as String? ?? 'predictive',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'domain': domain,
      'type': type,
      'question_text': questionText,
      'options': options,
      'correct_answers': correctAnswers,
      'explanation': explanation,
      'source': source,
      'topic': topic,
      'difficulty': difficulty,
      'approach': approach,
    };
  }

  /// Valuta se la risposta data dallo studente è corretta.
  /// [givenAnswer] ha la stessa forma di [correctAnswers] a seconda del tipo.
  bool isCorrect(dynamic givenAnswer) {
    if (type == 'single_choice') {
      final correct = (correctAnswers as List).first;
      return givenAnswer == correct;
    }
    if (type == 'multiple_response') {
      final correctSet = Set<String>.from(correctAnswers as List);
      final givenSet = Set<String>.from(givenAnswer as List? ?? []);
      return correctSet.length == givenSet.length &&
          correctSet.containsAll(givenSet);
    }
    if (type == 'matching' || type == 'pulldown') {
      final correctMap = Map<String, String>.from(correctAnswers as Map);
      final givenMap = Map<String, String>.from(givenAnswer as Map? ?? {});
      if (correctMap.length != givenMap.length) return false;
      for (final key in correctMap.keys) {
        if (givenMap[key] != correctMap[key]) return false;
      }
      return true;
    }
    if (type == 'point_and_click' || type == 'graphic_based') {
      final correct = (correctAnswers as List).first;
      return givenAnswer == correct;
    }
    return false;
  }
}
