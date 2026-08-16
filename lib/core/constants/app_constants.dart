/// Costanti globali dell'app: domini ECO 2026, tipi di domanda,
/// pesi ufficiali, stati di sessione. Un'unica fonte di verità
/// per evitare stringhe "magiche" sparse nel codice.
class AppConstants {
  AppConstants._();

  // ---------------------------------------------------------------------
  // DOMINI ECO 2026 — pesi ufficiali PMI confermati
  // ---------------------------------------------------------------------
  static const String domainPeople = 'people';
  static const String domainProcess = 'process';
  static const String domainBusinessEnvironment = 'business_environment';

  static const Map<String, double> domainWeights = {
    domainPeople: 0.33,
    domainProcess: 0.41,
    domainBusinessEnvironment: 0.26,
  };

  static const Map<String, String> domainLabels = {
    domainPeople: 'People',
    domainProcess: 'Process',
    domainBusinessEnvironment: 'Business Environment',
  };

  // ---------------------------------------------------------------------
  // VISIBILITÀ SPIEGAZIONE — a chi viene mostrata la spiegazione della
  // risposta corretta dopo il reveal: solo studente (comportamento
  // storico), solo trainer, o entrambi.
  // ---------------------------------------------------------------------
  static const String explanationVisibilityStudent = 'student';
  static const String explanationVisibilityTrainer = 'trainer';
  static const String explanationVisibilityBoth = 'both';

  // ---------------------------------------------------------------------
  // TIPI DI DOMANDA ECO 2026
  // ---------------------------------------------------------------------
  static const String typeSingleChoice = 'single_choice';
  static const String typeMultipleResponse = 'multiple_response';
  static const String typeMatching = 'matching';
  static const String typePulldown = 'pulldown';
  static const String typeCaseScenario = 'case_scenario';
  static const String typeHotspot = 'point_and_click';
  static const String typeGraphic = 'graphic_based';

  static const Map<String, String> typeLabels = {
    typeSingleChoice: 'Scelta singola',
    typeMultipleResponse: 'Risposta multipla',
    typeMatching: 'Abbinamento (drag & drop)',
    typePulldown: 'Menu a tendina',
    typeCaseScenario: 'Scenario',
    typeHotspot: 'Point & Click',
    typeGraphic: 'Basata su grafico',
  };

  // ---------------------------------------------------------------------
  // STATI SESSIONE
  // ---------------------------------------------------------------------
  static const String sessionLobby = 'lobby';
  static const String sessionRunning = 'running';
  static const String sessionPaused = 'paused';
  static const String sessionFinished = 'finished';

  // ---------------------------------------------------------------------
  // MODALITÀ FEEDBACK / TIMER (configurabili da Supabase o da app trainer)
  // ---------------------------------------------------------------------
  static const String feedbackImmediate = 'immediate';
  static const String feedbackEndOfExam = 'end_of_exam';

  static const String timerPerQuestion = 'per_question';
  static const String timerTotal = 'total';
  static const String timerNone = 'none';

  // Default esame di simulazione completo (ECO 2026)
  static const int fullExamQuestionCount = 180;
  static const int fullExamMinutes = 240;
}
