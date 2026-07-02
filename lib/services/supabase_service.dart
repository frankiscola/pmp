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

  /// Seleziona un set di domande rispettando i pesi ECO 2026
  /// (People 33% · Process 41% · Business Environment 26%).
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
    final weights = {'people': 0.33, 'process': 0.41, 'business_environment': 0.26};
    final result = <Question>[];
    final random = Random();
    weights.forEach((domain, weight) {
      final count = (totalCount * weight).round();
      final pool = List<Question>.from(byDomain[domain] ?? []);
      pool.shuffle(random);
      result.addAll(pool.take(count));
    });
    result.shuffle(random);
    return result;
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
      throw StateError('Devi essere autenticato come trainer per creare una sessione.');
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
    final inserted = await _client.from('exam_sessions').insert(row).select().single();
    return ExamSession.fromJson(inserted);
  }

  Future<String> _generateSessionCode() async {
    try {
      final result = await _client.rpc('generate_session_code');
      return result as String;
    } catch (_) {
      // Fallback lato client se la funzione SQL non è disponibile
      final random = Random();
      final number = 1000 + random.nextInt(8999);
      return 'PMP-$number';
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
    return _client.from('exam_sessions').update({'status': status}).eq('id', sessionId);
  }

  Future<void> goToQuestionIndex(String sessionId, int index) {
    return _client
        .from('exam_sessions')
        .update({'current_question_index': index}).eq('id', sessionId);
  }

  Future<void> finishSession(String sessionId) {
    return _client.from('exam_sessions').update({
      'status': 'finished',
      'finished_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);
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
    final inserted = await _client.from('participants').insert(row).select().single();
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
  Future<void> submitAnswer({
    required String sessionId,
    required String participantId,
    required Question question,
    required dynamic givenAnswer,
    required int timeSpentSeconds,
  }) async {
    final correct = question.isCorrect(givenAnswer);
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
      await _client.from('participants').update({
        'score': (participant['score'] as int? ?? 0) + 1,
        'domain_scores': domainScores,
      }).eq('id', participantId);
    }
  }

  Future<List<Answer>> fetchAnswersForQuestion(String sessionId, String questionId) async {
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
    final data = await _client.from('answers').select().eq('session_id', sessionId);
    return (data as List)
        .map((row) => Answer.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
