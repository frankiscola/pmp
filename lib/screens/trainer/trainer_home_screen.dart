import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../models/exam_settings.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import 'lobby_screen.dart';

/// Schermata del trainer per configurare e lanciare una nuova sessione:
/// modalità (Training / Simulazione), numero di domande, feedback e timer.
/// Tutti i parametri che l'utente voleva poter scegliere direttamente
/// dall'app, senza dover toccare Supabase manualmente.
class TrainerHomeScreen extends StatefulWidget {
  const TrainerHomeScreen({super.key});

  @override
  State<TrainerHomeScreen> createState() => _TrainerHomeScreenState();
}

class _TrainerHomeScreenState extends State<TrainerHomeScreen> {
  String _examMode = 'training';
  int _questionCount = 20;
  String _feedbackMode = AppConstants.feedbackImmediate;
  String _timerMode = AppConstants.timerPerQuestion;
  int _timerSecondsPerQuestion = 90;
  int _totalExamMinutes = AppConstants.fullExamMinutes; // default 240, come l'esame reale
  late final TextEditingController _totalExamMinutesController =
      TextEditingController(text: '$_totalExamMinutes');
  final FocusNode _totalExamMinutesFocusNode = FocusNode();
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    // Seleziona tutto il testo quando il campo riceve il focus: senza
    // questo, cliccando sul campo il valore di default "240" resta lì e
    // digitare un nuovo numero (es. "11") si concatena col vecchio invece
    // di sostituirlo, producendo valori assurdi come "24011" o simili.
    _totalExamMinutesFocusNode.addListener(() {
      if (_totalExamMinutesFocusNode.hasFocus) {
        _totalExamMinutesController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _totalExamMinutesController.text.length,
        );
      } else {
        // Il campo ha perso il focus: se è rimasto vuoto o con un valore
        // non valido (es. l'utente ha cancellato tutto senza scrivere
        // nulla di nuovo), lo riallineiamo all'ultimo valore valido invece
        // di lasciarlo visivamente vuoto.
        final parsed = int.tryParse(_totalExamMinutesController.text);
        if (parsed == null || parsed <= 0) {
          _totalExamMinutesController.text = '$_totalExamMinutes';
        }
      }
    });
  }

  @override
  void dispose() {
    _totalExamMinutesController.dispose();
    _totalExamMinutesFocusNode.dispose();
    super.dispose();
  }

  Future<void> _createSession() async {
    setState(() => _creating = true);
    try {
      final questions = await SupabaseService.instance.selectQuestionSet(
        _questionCount,
      );
      final settings = ExamSettings(
        feedbackMode: _feedbackMode,
        timerMode: _timerMode,
        timerSecondsPerQuestion: _timerSecondsPerQuestion,
        totalExamMinutes: _totalExamMinutes,
        examMode: _examMode,
        questionCount: _questionCount,
      );
      final session = await SupabaseService.instance.createSession(
        questions: questions,
        settings: settings,
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => LobbyScreen(session: session)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore nella creazione della sessione: $e')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nuova sessione'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => SupabaseService.instance.trainerSignOut(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Modalità esame',
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _modeChip(
                      'training',
                      'Training',
                      'Feedback immediato, quiz breve',
                    ),
                    const SizedBox(height: 8),
                    _modeChip(
                      'simulation',
                      'Simulazione',
                      'Come il vero esame, 180 domande',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Numero di domande',
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [10, 20, 30, 60, 180].map((n) {
                        final selected = _questionCount == n;
                        return ChoiceChip(
                          label: Text('$n'),
                          selected: selected,
                          onSelected: (_) => setState(() => _questionCount = n),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Feedback', style: AppTextStyles.titleMedium),
                    const SizedBox(height: 12),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: AppConstants.feedbackImmediate,
                      groupValue: _feedbackMode,
                      title: const Text('Immediato dopo ogni domanda'),
                      onChanged: (v) => setState(() => _feedbackMode = v!),
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: AppConstants.feedbackEndOfExam,
                      groupValue: _feedbackMode,
                      title: const Text('Solo a fine esame'),
                      onChanged: (v) => setState(() => _feedbackMode = v!),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Timer', style: AppTextStyles.titleMedium),
                    const SizedBox(height: 12),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: AppConstants.timerPerQuestion,
                      groupValue: _timerMode,
                      title: const Text('Per domanda'),
                      onChanged: (v) => setState(() => _timerMode = v!),
                    ),
                    if (_timerMode == AppConstants.timerPerQuestion)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 8),
                        child: Slider(
                          value: _timerSecondsPerQuestion.toDouble(),
                          min: 30,
                          max: 180,
                          divisions: 15,
                          label: '$_timerSecondsPerQuestion s',
                          onChanged: (v) => setState(
                            () => _timerSecondsPerQuestion = v.round(),
                          ),
                        ),
                      ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: AppConstants.timerTotal,
                      groupValue: _timerMode,
                      title: const Text('Totale per l\'intero esame'),
                      onChanged: (v) => setState(() => _timerMode = v!),
                    ),
                    if (_timerMode == AppConstants.timerTotal)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _totalExamMinutesController,
                                focusNode: _totalExamMinutesFocusNode,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Minuti totali',
                                  helperText:
                                      'Default 240, come l\'esame PMP reale',
                                  isDense: true,
                                ),
                                onChanged: (v) {
                                  final parsed = int.tryParse(v);
                                  if (parsed != null && parsed > 0) {
                                    setState(() => _totalExamMinutes = parsed);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: AppConstants.timerNone,
                      groupValue: _timerMode,
                      title: const Text('Nessun timer'),
                      onChanged: (v) => setState(() => _timerMode = v!),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Crea sessione',
                icon: Icons.play_circle_outline,
                fullWidth: true,
                loading: _creating,
                onPressed: _createSession,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeChip(String value, String title, String subtitle) {
    final selected = _examMode == value;
    return InkWell(
      onTap: () => setState(() => _examMode = value),
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.pmiGreenLight : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: selected ? AppColors.pmiGreen : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.pmiGreen : AppColors.textTertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
