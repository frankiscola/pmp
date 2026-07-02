import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exam_session.dart';
import '../models/participant.dart';
import '../models/answer.dart';

/// Espone stream realtime basati sulle subscription Supabase, usati per:
/// - far vedere al trainer chi entra in lobby in tempo reale
/// - avanzare automaticamente la domanda su tutti i telefoni degli studenti
/// - aggiornare la distribuzione delle risposte live nella dashboard
class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Stream della sessione — usato dagli studenti per sapere quando
  /// il trainer cambia domanda o chiude l'esame, e dal trainer stesso
  /// per riflettere lo stato corrente su più dispositivi.
  Stream<ExamSession?> watchSession(String sessionId) {
    return _client
        .from('exam_sessions')
        .stream(primaryKey: ['id'])
        .eq('id', sessionId)
        .map((rows) => rows.isEmpty ? null : ExamSession.fromJson(rows.first));
  }

  /// Stream dei partecipanti connessi — lobby live e classifica finale.
  Stream<List<Participant>> watchParticipants(String sessionId) {
    return _client
        .from('participants')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId)
        .order('score')
        .map((rows) => rows.map((r) => Participant.fromJson(r)).toList()
          ..sort((a, b) => b.score.compareTo(a.score)));
  }

  /// Stream delle risposte per la domanda corrente — alimenta il grafico
  /// a barre live nella dashboard del trainer ("18/22 hanno risposto").
  Stream<List<Answer>> watchAnswers(String sessionId) {
    return _client
        .from('answers')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId)
        .map((rows) => rows.map((r) => Answer.fromJson(r)).toList());
  }
}
