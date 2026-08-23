import '../models/answer.dart';
import '../models/question.dart';

/// Risultato/copertura per un dominio ECO 2026 (people / process /
/// business_environment) su un insieme di risposte.
class DomainStat {
  final String domain;
  final int correct;
  final int total;

  const DomainStat({
    required this.domain,
    required this.correct,
    required this.total,
  });

  double get accuracy => total == 0 ? 0 : correct / total;
}

/// Quanto una singola domanda è stata sbagliata, su un insieme di risposte.
class QuestionMissStat {
  final Question question;
  final int wrong;
  final int total;

  const QuestionMissStat({
    required this.question,
    required this.wrong,
    required this.total,
  });

  double get missRate => total == 0 ? 0 : wrong / total;
}

/// Snapshot dell'andamento per dominio di UNA sessione conclusa — usato per
/// costruire il grafico "andamento del gruppo nel tempo" (una barra/riga per
/// ogni giornata di corso).
class GroupSessionSnapshot {
  final DateTime date;
  final Map<String, DomainStat> domainStats;

  const GroupSessionSnapshot({required this.date, required this.domainStats});
}

/// Tutte le funzioni di aggregazione statistica dell'app — pure, senza
/// dipendenze da Supabase, così sono facilmente riutilizzabili sia lato
/// studente (report personale) sia lato trainer (dashboard live e risultati
/// finali) partendo dagli stessi dati grezzi (domande + risposte).
class AnalyticsService {
  AnalyticsService._();

  /// Ordine di visualizzazione standard dei 3 domini ECO 2026.
  static const List<String> domainOrder = [
    'people',
    'process',
    'business_environment',
  ];

  /// Accuratezza per dominio su un set di risposte date. Sempre presenti
  /// tutti e 3 i domini nella mappa risultato, anche con total: 0.
  static Map<String, DomainStat> domainStats(
    List<Question> questions,
    List<Answer> answers,
  ) {
    final byId = {for (final q in questions) q.id: q};
    final correct = <String, int>{};
    final total = <String, int>{};
    for (final a in answers) {
      final q = byId[a.questionId];
      if (q == null) continue;
      total[q.domain] = (total[q.domain] ?? 0) + 1;
      if (a.isCorrect) correct[q.domain] = (correct[q.domain] ?? 0) + 1;
    }
    return {
      for (final d in domainOrder)
        d: DomainStat(domain: d, correct: correct[d] ?? 0, total: total[d] ?? 0),
    };
  }

  /// Aggrega più [DomainStat] map (es. una per sessione) in un'unica mappa
  /// cumulativa — usato per calcolare l'accuratezza storica di un gruppo su
  /// tutte le sue sessioni concluse, come base per la selezione adattiva.
  static Map<String, DomainStat> combineDomainStats(
    Iterable<Map<String, DomainStat>> snapshots,
  ) {
    final correct = <String, int>{};
    final total = <String, int>{};
    for (final snap in snapshots) {
      for (final entry in snap.entries) {
        correct[entry.key] = (correct[entry.key] ?? 0) + entry.value.correct;
        total[entry.key] = (total[entry.key] ?? 0) + entry.value.total;
      }
    }
    return {
      for (final d in domainOrder)
        d: DomainStat(domain: d, correct: correct[d] ?? 0, total: total[d] ?? 0),
    };
  }

  /// Le domande più sbagliate su un set di risposte, ordinate per % di
  /// errore decrescente. Solo domande con almeno un errore compaiono.
  static List<QuestionMissStat> mostMissed(
    List<Question> questions,
    List<Answer> answers, {
    int limit = 5,
  }) {
    final byId = {for (final q in questions) q.id: q};
    final wrong = <String, int>{};
    final total = <String, int>{};
    for (final a in answers) {
      total[a.questionId] = (total[a.questionId] ?? 0) + 1;
      if (!a.isCorrect) wrong[a.questionId] = (wrong[a.questionId] ?? 0) + 1;
    }
    final stats =
        total.entries
            .map((e) {
              final question = byId[e.key];
              if (question == null) return null;
              return QuestionMissStat(
                question: question,
                wrong: wrong[e.key] ?? 0,
                total: e.value,
              );
            })
            .whereType<QuestionMissStat>()
            .where((s) => s.wrong > 0)
            .toList()
          ..sort((a, b) {
            final byRate = b.missRate.compareTo(a.missRate);
            return byRate != 0 ? byRate : b.wrong.compareTo(a.wrong);
          });
    return stats.take(limit).toList();
  }
}
