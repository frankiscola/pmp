import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../models/question.dart';
import '../models/exam_session.dart';
import '../models/exam_settings.dart';
import '../models/participant.dart';
import '../models/answer.dart';
import '../models/group.dart';

/// Esito della selezione di un set di domande. [reusedCount] è > 0 solo
/// quando il pool di domande "nuove" (mai viste dal gruppo) non bastava a
/// coprire il numero richiesto, e quindi alcune domande già proposte sono
/// state ripescate per completare il set — il chiamante può avvisare il
/// trainer in questo caso.
class QuestionSelectionResult {
  final List<Question> questions;
  final int reusedCount;

  const QuestionSelectionResult({
    required this.questions,
    this.reusedCount = 0,
  });
}

/// Wrapper attorno al client Supabase: ogni chiamata al database passa
/// da qui. Tenere tutta la logica di accesso dati in un unico posto rende
/// più semplice cambiare schema o aggiungere caching in futuro.
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get _client => Supabase.instance.client;

  // ---------------------------------------------------------------------
  // AUTH TRAINER
  // ---------------------------------------------------------------------
  Future<AuthResponse> trainerSignIn(String email, String password) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> trainerSignOut() => _client.auth.signOut();

  User? get currentTrainer => _client.auth.currentUser;

  // ---------------------------------------------------------------------
  // DOMANDE
  // ---------------------------------------------------------------------
  Future<List<Question>> fetchQuestions({
    String? domain,
    String? type,
    int? limit,
  }) async {
    var query = _client.from('questions').select();
    if (domain != null) query = query.eq('domain', domain);
    if (type != null) query = query.eq('type', type);
    final data = await query;
    final questions = (data as List)
        .map((row) => Question.fromJson(row as Map<String, dynamic>))
        .toList();
    if (limit != null && questions.length > limit) {
      questions.shuffle();
      return questions.sublist(0, limit);
    }
    return questions;
  }

  /// Seleziona un set di domande rispettando (quando possibile) i pesi ECO 2026
  /// (People 33% · Process 41% · Business Environment 26%). Se un dominio non
  /// ha abbastanza domande disponibili per la sua quota, lo shortfall viene
  /// recuperato dagli altri domini SELEZIONATI — così il conteggio finale
  /// richiesto (es. 20) viene rispettato quando possibile.
  ///
  /// Se [excludeIds] è fornito (tipicamente lo storico di un [Group]), quelle
  /// domande vengono escluse dal pool prima della selezione pesata, per non
  /// riproporre allo stesso gruppo domande già viste in giornate precedenti.
  /// Solo se il pool "nuovo" non basta a coprire [totalCount], si ripesca
  /// dalle domande escluse — e in quel caso [QuestionSelectionResult.reusedCount]
  /// riporta quante sono state riproposte, così il chiamante può avvisare il
  /// trainer.
  ///
  /// Se [domains] è fornito (sottoinsieme di 'people'/'process'/
  /// 'business_environment'), la selezione pesca SOLO da quei domini — sia
  /// nella quota principale sia nell'eventuale ripesca — e i pesi ECO 2026
  /// vengono rinormalizzati sul sottoinsieme scelto (es. solo People+Process
  /// → 33/(33+41) e 41/(33+41), invece di un 50:50 arbitrario). Se null o
  /// vuoto, si usano tutti e tre i domini (comportamento "esame completo").
  Future<QuestionSelectionResult> selectQuestionSet(
    int totalCount, {
    Set<String>? excludeIds,
    Set<String>? domains,
  }) async {
    final all = await fetchQuestions();
    final byDomainFilter = (domains == null || domains.isEmpty)
        ? all
        : all.where((q) => domains.contains(q.domain)).toList();

    final exclude = excludeIds ?? const <String>{};
    final available = exclude.isEmpty
        ? byDomainFilter
        : byDomainFilter.where((q) => !exclude.contains(q.id)).toList();

    final selected = _weightedPick(available, totalCount, domains: domains);
    var reused = 0;

    if (selected.length < totalCount && exclude.isNotEmpty) {
      // Il gruppo ha già visto troppe domande: il pool "nuovo" non basta.
      // Ripeschiamo dalle domande già usate (ma sempre solo nei domini
      // selezionati) pur di garantire il numero di domande richiesto.
      final chosenIds = selected.map((q) => q.id).toSet();
      final fallbackPool = byDomainFilter
          .where((q) => !chosenIds.contains(q.id))
          .toList();
      fallbackPool.shuffle(Random());
      final needed = (totalCount - selected.length).clamp(
        0,
        fallbackPool.length,
      );
      final topUp = fallbackPool.take(needed).toList();
      selected.addAll(topUp);
      reused = topUp.length;
    }

    return QuestionSelectionResult(questions: selected, reusedCount: reused);
  }

  /// Estrae fino a [totalCount] domande da [pool] rispettando (quando
  /// possibile) i pesi ECO 2026 per dominio, rinormalizzati sui soli
  /// [domains] se specificato (altrimenti tutti e tre). Può restituire
  /// meno di [totalCount] domande se [pool] non ne contiene abbastanza.
  List<Question> _weightedPick(
    List<Question> pool,
    int totalCount, {
    Set<String>? domains,
  }) {
    final selectedDomains = (domains == null || domains.isEmpty)
        ? AppConstants.domainWeights.keys.toSet()
        : domains;

    final byDomain = <String, List<Question>>{
      for (final d in selectedDomains) d: <Question>[],
    };
    for (final q in pool) {
      byDomain[q.domain]?.add(q);
    }

    // Rinormalizza i pesi ECO 2026 sui soli domini selezionati (sommano a 1
    // sul sottoinsieme scelto, mantenendo le proporzioni relative tra loro).
    final selectedWeightSum = selectedDomains.fold<double>(
      0,
      (sum, d) => sum + (AppConstants.domainWeights[d] ?? 0),
    );
    final normalizedWeights = {
      for (final d in selectedDomains)
        d: selectedWeightSum > 0
            ? (AppConstants.domainWeights[d] ?? 0) / selectedWeightSum
            : 1 / selectedDomains.length,
    };

    final random = Random();
    final result = <Question>[];
    final usedIds = <String>{};
    var shortfall = 0;

    // Prima passata: prova a prendere la quota pesata da ogni dominio
    normalizedWeights.forEach((domain, weight) {
      final desired = (totalCount * weight).round();
      final domainPool = List<Question>.from(byDomain[domain] ?? []);
      domainPool.shuffle(random);
      final taken = domainPool.take(desired).toList();
      result.addAll(taken);
      usedIds.addAll(taken.map((q) => q.id));
      if (taken.length < desired) {
        shortfall += desired - taken.length;
      }
    });

    // Seconda passata: colma lo shortfall pescando dalle domande rimanenti
    // ma SOLO all'interno dei domini selezionati (pool), mai da domini
    // esclusi dal trainer.
    if (shortfall > 0) {
      final remaining = pool.where((q) => !usedIds.contains(q.id)).toList();
      remaining.shuffle(random);
      final topUp = remaining.take(shortfall).toList();
      result.addAll(topUp);
      usedIds.addAll(topUp.map((q) => q.id));
    }

    result.shuffle(random);
    return result.take(totalCount.clamp(0, pool.length)).toList();
  }

  // ---------------------------------------------------------------------
  // GRUPPI — per non riproporre le stesse domande allo stesso gruppo di
  // studenti su più giornate consecutive.
  // ---------------------------------------------------------------------

  /// Tutti i gruppi creati dal trainer attualmente autenticato, più
  /// recenti prima.
  Future<List<Group>> fetchGroups() async {
    final trainerId = currentTrainer?.id;
    if (trainerId == null) return [];
    final data = await _client
        .from('groups')
        .select()
        .eq('trainer_id', trainerId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((row) => Group.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<Group> createGroup(String name) async {
    final trainerId = currentTrainer?.id;
    if (trainerId == null) {
      throw StateError(
        'Devi essere autenticato come trainer per creare un gruppo.',
      );
    }
    final inserted = await _client
        .from('groups')
        .insert({
          'trainer_id': trainerId,
          'name': name.trim(),
          'used_question_ids': <String>[],
        })
        .select()
        .single();
    return Group.fromJson(inserted);
  }

  /// Aggiunge gli id delle domande appena proposte allo storico del gruppo,
  /// così non ricompariranno nelle prossime sessioni con lo stesso gruppo.
  /// Va chiamato subito dopo aver creato una sessione per quel gruppo.
  Future<void> markQuestionsUsed(
    String groupId,
    List<String> questionIds,
  ) async {
    if (questionIds.isEmpty) return;
    final current = await _client
        .from('groups')
        .select('used_question_ids')
        .eq('id', groupId)
        .single();
    final existing = <String>{
      ...List<String>.from(current['used_question_ids'] as List? ?? []),
      ...questionIds,
    };
    await _client
        .from('groups')
        .update({
          'used_question_ids': existing.toList(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', groupId);
  }

  /// Svuota lo storico delle domande già proposte al gruppo: alla prossima
  /// sessione tutte le domande torneranno disponibili per quel gruppo.
  Future<void> resetGroupQuestions(String groupId) async {
    await _client
        .from('groups')
        .update({
          'used_question_ids': <String>[],
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', groupId);
  }

  Future<void> deleteGroup(String groupId) async {
    await _client.from('groups').delete().eq('id', groupId);
  }

  // ---------------------------------------------------------------------
  // EXAM SETTINGS (preset "training" / "simulation")
  // ---------------------------------------------------------------------
  Future<ExamSettings> fetchSettingsPreset(String presetName) async {
    final data = await _client
        .from('exam_settings')
        .select()
        .eq('name', presetName)
        .maybeSingle();
    if (data == null) return const ExamSettings();
    return ExamSettings.fromJson(data);
  }

  // ---------------------------------------------------------------------
  // SESSIONI D'ESAME (lato trainer)
  // ---------------------------------------------------------------------
  Future<ExamSession> createSession({
    required List<Question> questions,
    required ExamSettings settings,
  }) async {
    final trainerId = currentTrainer?.id;
    if (trainerId == null) {
      throw StateError(
        'Devi essere autenticato come trainer per creare una sessione.',
      );
    }
    final code = await _generateSessionCode();
    final row = {
      'code': code,
      'trainer_id': trainerId,
      'status': 'lobby',
      'current_question_index': 0,
      'question_ids': questions.map((q) => q.id).toList(),
      'settings': settings.toJson(),
    };
    final inserted = await _client
        .from('exam_sessions')
        .insert(row)
        .select()
        .single();
    return ExamSession.fromJson(inserted);
  }

  Future<String> _generateSessionCode() async {
    try {
      final result = await _client.rpc('generate_session_code');
      return result as String;
    } catch (_) {
      // Fallback lato client se la funzione SQL non è disponibile:
      // codice numerico a 6 cifre, facile da digitare su tastiera telefono
      // (si apre automaticamente in modalità numerica, senza simboli).
      final random = Random();
      final number = 100000 + random.nextInt(900000);
      return '$number';
    }
  }

  Future<ExamSession?> fetchSessionByCode(String code) async {
    final data = await _client
        .from('exam_sessions')
        .select()
        .eq('code', code.toUpperCase())
        .maybeSingle();
    if (data == null) return null;
    return ExamSession.fromJson(data);
  }

  Future<void> updateSessionStatus(String sessionId, String status) {
    return _client
        .from('exam_sessions')
        .update({'status': status})
        .eq('id', sessionId);
  }

  /// Avvia la sessione: imposta lo status su "running" E registra
  /// `started_at`. Quest'ultimo è indispensabile per il timer in modalità
  /// "intero esame" (timerMode == total), che calcola i secondi rimanenti
  /// come `totalExamMinutes - (now - startedAt)`. Usare SEMPRE questo
  /// metodo per avviare una sessione, non updateSessionStatus direttamente,
  /// altrimenti startedAt resta null e quel timer non parte mai.
  ///
  /// IMPORTANTE: si usa `.toUtc()` prima di serializzare. La colonna è
  /// `timestamptz` e Postgres, se riceve una stringa SENZA fuso orario
  /// esplicito (quello che produce `DateTime.now().toIso8601String()` con
  /// l'ora locale), la interpreta come se fosse già UTC — per un utente in
  /// Italia in estate (UTC+2) questo sposta `started_at` di 2 ore nel
  /// "futuro", facendo apparire il tempo trascorso negativo e quindi il
  /// countdown molto più lungo del dovuto (es. 12 minuti configurati
  /// mostrati come ~132). `.toUtc()` genera una stringa con il suffisso
  /// "Z", inequivocabile, e risolve il problema alla radice.
  Future<void> startSession(String sessionId) {
    return _client
        .from('exam_sessions')
        .update({
          'status': 'running',
          'started_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', sessionId);
  }

  Future<void> goToQuestionIndex(String sessionId, int index) {
    return _client
        .from('exam_sessions')
        .update({
          'current_question_index': index,
          'answer_revealed':
              false, // reset: la nuova domanda parte non rivelata
        })
        .eq('id', sessionId);
  }

  /// Il trainer preme "Rivela risposta": tutti gli studenti connessi vedono
  /// istantaneamente (via realtime) corretto/sbagliato e la spiegazione.
  Future<void> revealAnswer(String sessionId) {
    return _client
        .from('exam_sessions')
        .update({'answer_revealed': true})
        .eq('id', sessionId);
  }

  Future<void> finishSession(String sessionId) {
    return _client
        .from('exam_sessions')
        .update({
          'status': 'finished',
          'finished_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', sessionId);
  }

  /// Mette la sessione in pausa (Break): gli studenti vedono la schermata
  /// di break e il countdown dell'esame (se in modalità "intero esame") si
  /// congela immediatamente, perché [pausedAt] diventa il nuovo riferimento
  /// per il calcolo del tempo trascorso finché non si riprende.
  Future<void> pauseSession(String sessionId) {
    return _client
        .from('exam_sessions')
        .update({
          'status': AppConstants.sessionPaused,
          'paused_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', sessionId);
  }

  /// Riprende una sessione in pausa: somma la durata di questa pausa a
  /// [pausedSecondsTotal] (così il tempo di Break non viene mai conteggiato
  /// nel countdown) e torna allo stato "running".
  Future<void> resumeSession(ExamSession session) async {
    final pausedAt = session.pausedAt;
    final thisPauseDuration = pausedAt != null
        ? DateTime.now().toUtc().difference(pausedAt).inSeconds
        : 0;
    await _client
        .from('exam_sessions')
        .update({
          'status': AppConstants.sessionRunning,
          'paused_at': null,
          'paused_seconds_total':
              session.pausedSecondsTotal + thisPauseDuration,
        })
        .eq('id', session.id);
  }

  // ---------------------------------------------------------------------
  // PARTECIPANTI (lato studente)
  // ---------------------------------------------------------------------
  Future<Participant> joinSession(String sessionId, String name) async {
    final row = {
      'session_id': sessionId,
      'name': name,
      'joined_at': DateTime.now().toUtc().toIso8601String(),
      'score': 0,
      'domain_scores': {'people': 0, 'process': 0, 'business_environment': 0},
    };
    final inserted = await _client
        .from('participants')
        .insert(row)
        .select()
        .single();
    return Participant.fromJson(inserted);
  }

  Future<List<Participant>> fetchParticipants(String sessionId) async {
    final data = await _client
        .from('participants')
        .select()
        .eq('session_id', sessionId)
        .order('score', ascending: false);
    return (data as List)
        .map((row) => Participant.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------
  // RISPOSTE
  // ---------------------------------------------------------------------
  /// Salva la risposta di uno studente. Se lo studente aveva già risposto a
  /// questa domanda (perché ha cambiato idea prima del "Rivela risposta" del
  /// trainer), AGGIORNA la risposta esistente invece di inserirne una nuova,
  /// correggendo anche il punteggio se la correttezza è cambiata.
  Future<void> submitAnswer({
    required String sessionId,
    required String participantId,
    required Question question,
    required dynamic givenAnswer,
    required int timeSpentSeconds,
  }) async {
    final correct = question.isCorrect(givenAnswer);

    final existing = await _client
        .from('answers')
        .select()
        .eq('session_id', sessionId)
        .eq('participant_id', participantId)
        .eq('question_id', question.id)
        .maybeSingle();

    if (existing != null) {
      // Lo studente aveva già risposto: aggiorna la riga esistente.
      await _client
          .from('answers')
          .update({
            'given_answer': givenAnswer,
            'is_correct': correct,
            'time_spent_seconds': timeSpentSeconds,
            'answered_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', existing['id']);

      final wasCorrect = existing['is_correct'] as bool? ?? false;
      if (wasCorrect != correct) {
        // La correttezza è cambiata: correggi punteggio totale e per dominio.
        final participant = await _client
            .from('participants')
            .select()
            .eq('id', participantId)
            .single();
        final domainScores = Map<String, int>.from(
          (participant['domain_scores'] as Map?) ?? {},
        );
        final delta = correct ? 1 : -1;
        domainScores[question.domain] =
            (domainScores[question.domain] ?? 0) + delta;
        await _client
            .from('participants')
            .update({
              'score': (participant['score'] as int? ?? 0) + delta,
              'domain_scores': domainScores,
            })
            .eq('id', participantId);
      }
      return;
    }

    // Prima risposta a questa domanda: inserisci normalmente.
    await _client.from('answers').insert({
      'session_id': sessionId,
      'participant_id': participantId,
      'question_id': question.id,
      'given_answer': givenAnswer,
      'is_correct': correct,
      'time_spent_seconds': timeSpentSeconds,
      'answered_at': DateTime.now().toUtc().toIso8601String(),
    });

    if (correct) {
      final participant = await _client
          .from('participants')
          .select()
          .eq('id', participantId)
          .single();
      final domainScores = Map<String, int>.from(
        (participant['domain_scores'] as Map?) ?? {},
      );
      domainScores[question.domain] = (domainScores[question.domain] ?? 0) + 1;
      await _client
          .from('participants')
          .update({
            'score': (participant['score'] as int? ?? 0) + 1,
            'domain_scores': domainScores,
          })
          .eq('id', participantId);
    }
  }

  Future<List<Answer>> fetchAnswersForQuestion(
    String sessionId,
    String questionId,
  ) async {
    final data = await _client
        .from('answers')
        .select()
        .eq('session_id', sessionId)
        .eq('question_id', questionId);
    return (data as List)
        .map((row) => Answer.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<Answer>> fetchAllAnswers(String sessionId) async {
    final data = await _client
        .from('answers')
        .select()
        .eq('session_id', sessionId);
    return (data as List)
        .map((row) => Answer.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
