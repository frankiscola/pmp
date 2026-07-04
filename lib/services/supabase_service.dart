import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/question.dart';
import '../models/exam_session.dart';
import '../models/exam_settings.dart';
import '../models/participant.dart';
import '../models/answer.dart';

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
  /// recuperato dagli altri domini — così il conteggio finale richiesto
  /// (es. 20) viene sempre rispettato, invece di restituire un set più corto.
  Future<List<Question>> selectQuestionSet(int totalCount) async {
    final all = await fetchQuestions();
    final byDomain = <String, List<Question>>{
      'people': [],
      'process': [],
      'business_environment': [],
    };
    for (final q in all) {
      byDomain[q.domain]?.add(q);
    }
    final weights = {
      'people': 0.33,
      'process': 0.41,
      'business_environment': 0.26,
    };
    final random = Random();
    final result = <Question>[];
    final usedIds = <String>{};
    var shortfall = 0;

    // Prima passata: prova a prendere la quota pesata da ogni dominio
    weights.forEach((domain, weight) {
      final desired = (totalCount * weight).round();
      final pool = List<Question>.from(byDomain[domain] ?? []);
      pool.shuffle(random);
      final taken = pool.take(desired).toList();
      result.addAll(taken);
      usedIds.addAll(taken.map((q) => q.id));
      if (taken.length < desired) {
        shortfall += desired - taken.length;
      }
    });

    // Seconda passata: colma lo shortfall pescando da TUTTE le domande
    // rimanenti (di qualunque dominio), per raggiungere comunque totalCount.
    if (shortfall > 0) {
      final remaining = all.where((q) => !usedIds.contains(q.id)).toList();
      remaining.shuffle(random);
      final topUp = remaining.take(shortfall).toList();
      result.addAll(topUp);
      usedIds.addAll(topUp.map((q) => q.id));
    }

    result.shuffle(random);
    // Non superare mai il numero di domande realmente disponibili nel DB.
    return result.take(totalCount.clamp(0, all.length)).toList();
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
          'finished_at': DateTime.now().toIso8601String(),
        })
        .eq('id', sessionId);
  }

  // ---------------------------------------------------------------------
  // PARTECIPANTI (lato studente)
  // ---------------------------------------------------------------------
  Future<Participant> joinSession(String sessionId, String name) async {
    final row = {
      'session_id': sessionId,
      'name': name,
      'joined_at': DateTime.now().toIso8601String(),
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
            'answered_at': DateTime.now().toIso8601String(),
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
      'answered_at': DateTime.now().toIso8601String(),
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
