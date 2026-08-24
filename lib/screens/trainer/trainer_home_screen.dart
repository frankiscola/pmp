import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../models/exam_settings.dart';
import '../../models/group.dart';
import '../../services/analytics_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import 'group_selection_screen.dart';
import 'lobby_screen.dart';

/// Schermata del trainer per configurare e lanciare una nuova sessione:
/// modalità (Training / Simulazione), numero di domande, feedback e timer.
/// Tutti i parametri che l'utente voleva poter scegliere direttamente
/// dall'app, senza dover toccare Supabase manualmente.
///
/// Se [group] è impostato, le domande già proposte a quel gruppo nelle
/// sessioni precedenti vengono escluse dalla selezione, per non ripeterle
/// su più giornate consecutive con la stessa classe.
class TrainerHomeScreen extends StatefulWidget {
  final Group? group;

  const TrainerHomeScreen({super.key, this.group});

  @override
  State<TrainerHomeScreen> createState() => _TrainerHomeScreenState();
}

class _TrainerHomeScreenState extends State<TrainerHomeScreen> {
  String _examMode = 'training';
  int _questionCount = 20;
  String _feedbackMode = AppConstants.feedbackImmediate;

  /// A chi mostrare la spiegazione dopo il reveal. Default 'both': utile
  /// sia per lo studente che rivede subito perché ha sbagliato, sia per il
  /// trainer che vuole commentarla a voce in aula senza dover leggere la
  /// domanda a memoria.
  String _explanationVisibility = AppConstants.explanationVisibilityBoth;

  /// Se mostrare agli studenti (icona in alto durante l'esame) e nel
  /// dashboard live del trainer la classifica in tempo reale. Default
  /// spenta: in molti contesti d'aula la competizione visibile mette
  /// pressione o distrae — il trainer la accende solo se la vuole.
  bool _showLeaderboard = false;
  String _timerMode = AppConstants.timerPerQuestion;
  int _timerSecondsPerQuestion = 90;
  int _totalExamMinutes = AppConstants.fullExamMinutes; // default 240, come l'esame reale
  late final TextEditingController _totalExamMinutesController =
      TextEditingController(text: '$_totalExamMinutes');
  final FocusNode _totalExamMinutesFocusNode = FocusNode();
  bool _creating = false;

  /// Domini da includere nella sessione. Di default tutti e tre (esame
  /// completo). Selezionandone solo alcuni, le domande vengono estratte
  /// esclusivamente da quelli, con le proporzioni ECO 2026 rinormalizzate
  /// sul sottoinsieme scelto — così una sessione "solo Business
  /// Environment" prende domande solo da lì, mentre "People + Process"
  /// rispetta il rapporto 33:41 tra i due invece di un 50:50 arbitrario.
  Set<String> _selectedDomains = {
    AppConstants.domainPeople,
    AppConstants.domainProcess,
    AppConstants.domainBusinessEnvironment,
  };

  /// Copia locale del gruppo, aggiornata dopo ogni sessione creata così il
  /// conteggio "domande già proposte" mostrato in questa schermata resta
  /// corretto senza dover ricaricare da Supabase.
  Group? _group;

  /// Se true (e c'è un gruppo selezionato con almeno una sessione conclusa
  /// alle spalle), le domande vengono pescate più spesso dai domini dove il
  /// gruppo ha storicamente performato peggio, invece dei pesi ECO fissi.
  /// Agisce SOLO all'interno dei domini eventualmente scelti in
  /// [_selectedDomains] — non li allarga né li restringe.
  bool _adaptiveSelection = true;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
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
      final excludeIds = _group != null
          ? _group!.usedQuestionIds.toSet()
          : null;

      Map<String, double>? domainAccuracy;
      if (_group != null && _adaptiveSelection) {
        final trend = await SupabaseService.instance.fetchGroupSessionTrend(
          _group!.id,
        );
        if (trend.isNotEmpty) {
          final combined = AnalyticsService.combineDomainStats(
            trend.map((s) => s.domainStats),
          );
          domainAccuracy = {
            for (final entry in combined.entries)
              if (entry.value.total > 0) entry.key: entry.value.accuracy,
          };
        }
      }

      final result = await SupabaseService.instance.selectQuestionSet(
        _questionCount,
        excludeIds: excludeIds,
        domains: _selectedDomains,
        domainAccuracy: domainAccuracy,
      );
      final settings = ExamSettings(
        feedbackMode: _feedbackMode,
        timerMode: _timerMode,
        timerSecondsPerQuestion: _timerSecondsPerQuestion,
        totalExamMinutes: _totalExamMinutes,
        examMode: _examMode,
        questionCount: _questionCount,
        explanationVisibility: _explanationVisibility,
        showLeaderboard: _showLeaderboard,
      );
      final session = await SupabaseService.instance.createSession(
        questions: result.questions,
        settings: settings,
        groupId: _group?.id,
      );

      if (_group != null) {
        final questionIds = result.questions.map((q) => q.id).toList();
        await SupabaseService.instance.markQuestionsUsed(
          _group!.id,
          questionIds,
        );
        _group = _group!.copyWith(
          usedQuestionIds: {..._group!.usedQuestionIds, ...questionIds}
              .toList(),
        );
      }

      if (!mounted) return;

      if (domainAccuracy != null && domainAccuracy.isNotEmpty) {
        final weakest = domainAccuracy.entries.reduce(
          (a, b) => a.value <= b.value ? a : b,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Selezione adattiva attiva: più domande su '
              '${AppConstants.domainLabels[weakest.key] ?? weakest.key} '
              '(dominio più debole finora per "${_group?.name}", '
              '${(weakest.value * 100).round()}% di accuratezza).',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }

      if (result.reusedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.warning,
            content: Text(
              '"${_group?.name}" ha già visto quasi tutte le domande '
              'disponibili: ${result.reusedCount} sono state riproposte per '
              'completare il set. Valuta un reset o amplia il database.',
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }

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

  Future<void> _resetGroup() async {
    final group = _group;
    if (group == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset domande gruppo'),
        content: Text(
          'Vuoi svuotare lo storico delle ${group.usedQuestionIds.length} '
          'domande già proposte a "${group.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await SupabaseService.instance.resetGroupQuestions(group.id);
    if (!mounted) return;
    setState(() => _group = group.copyWith(usedQuestionIds: const []));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Storico di "${group.name}" azzerato.')),
    );
  }

  void _changeGroup() {
    // GroupSelectionScreen naviga già direttamente a una nuova
    // TrainerHomeScreen quando si sceglie/crea un gruppo: questa vecchia
    // istanza resta semplicemente sotto nello stack di navigazione, e il
    // trainer può tornare indietro con il pulsante "back".
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GroupSelectionScreen()),
    );
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
              _buildGroupBanner(),
              const SizedBox(height: 16),
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
              // In modalità "Simulazione" numero di domande e domini sono
              // fissi (180 domande, tutti e tre i domini in proporzioni ECO
              // 2026) — nessuna scelta da fare, quindi niente card da
              // mostrare. Tornando a "Training" ricompaiono con l'ultima
              // selezione manuale fatta prima di passare a Simulazione.
              if (_examMode != 'simulation') ...[
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
                            onSelected: (_) =>
                                setState(() => _questionCount = n),
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
                      const Text('Domini', style: AppTextStyles.titleMedium),
                      const SizedBox(height: 4),
                      Text(_domainsSubtitle(), style: AppTextStyles.caption),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            [
                              AppConstants.domainPeople,
                              AppConstants.domainProcess,
                              AppConstants.domainBusinessEnvironment,
                            ].map((domain) {
                              final selected = _selectedDomains.contains(
                                domain,
                              );
                              return FilterChip(
                                label: Text(
                                  AppConstants.domainLabels[domain] ?? domain,
                                ),
                                selected: selected,
                                selectedColor: AppColors.domainColor(
                                  domain,
                                ).withValues(alpha: 0.25),
                                checkmarkColor: AppColors.domainColor(domain),
                                onSelected: (nowSelected) {
                                  setState(() {
                                    if (nowSelected) {
                                      _selectedDomains.add(domain);
                                    } else if (_selectedDomains.length > 1) {
                                      // Non permettere di deselezionare
                                      // l'ultimo dominio rimasto: una
                                      // sessione deve avere sempre almeno un
                                      // dominio da cui pescare le domande.
                                      _selectedDomains.remove(domain);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
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
                    const Text(
                      'Spiegazione',
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'A chi mostrare la spiegazione quando il trainer '
                      'rivela la risposta corretta.',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: 12),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: AppConstants.explanationVisibilityStudent,
                      groupValue: _explanationVisibility,
                      title: const Text('Solo studente'),
                      onChanged: (v) =>
                          setState(() => _explanationVisibility = v!),
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: AppConstants.explanationVisibilityTrainer,
                      groupValue: _explanationVisibility,
                      title: const Text('Solo trainer'),
                      onChanged: (v) =>
                          setState(() => _explanationVisibility = v!),
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: AppConstants.explanationVisibilityBoth,
                      groupValue: _explanationVisibility,
                      title: const Text('Entrambi'),
                      onChanged: (v) =>
                          setState(() => _explanationVisibility = v!),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _showLeaderboard,
                  onChanged: (v) => setState(() => _showLeaderboard = v),
                  title: const Text(
                    'Classifica live',
                    style: AppTextStyles.titleMedium,
                  ),
                  subtitle: const Text(
                    'Se attiva, gli studenti possono aprire la classifica '
                    'in tempo reale durante l\'esame (icona in alto) e il '
                    'trainer la vede nel dashboard live.',
                    style: AppTextStyles.caption,
                  ),
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

  /// Sottotitolo della card "Domini": riflette SEMPRE la combinazione
  /// effettivamente selezionata (mai un esempio fisso che potrebbe non
  /// c'entrare nulla con quello che il trainer ha scelto in quel momento).
  /// Con 2+ domini, mostra le percentuali ECO 2026 rinormalizzate sul
  /// sottoinsieme scelto — le stesse usate davvero da selectQuestionSet.
  String _domainsSubtitle() {
    if (_selectedDomains.length == 3) {
      final parts = [
        AppConstants.domainPeople,
        AppConstants.domainProcess,
        AppConstants.domainBusinessEnvironment,
      ].map((d) {
        final pct = (AppConstants.domainWeights[d]! * 100).round();
        return '${AppConstants.domainLabels[d]} $pct%';
      }).join(' · ');
      return 'Tutti e tre i domini, nelle proporzioni ufficiali ECO 2026 ($parts).';
    }
    if (_selectedDomains.length == 1) {
      final domain = _selectedDomains.first;
      return 'Solo domande di dominio ${AppConstants.domainLabels[domain]}.';
    }
    // 2 domini selezionati: rinormalizza i pesi ECO 2026 SOLO su questi due,
    // esattamente come fa selectQuestionSet, e mostra il rapporto reale.
    final weightSum = _selectedDomains.fold<double>(
      0,
      (sum, d) => sum + (AppConstants.domainWeights[d] ?? 0),
    );
    final parts = _selectedDomains.map((d) {
      final pct = weightSum > 0
          ? ((AppConstants.domainWeights[d] ?? 0) / weightSum * 100).round()
          : (100 / _selectedDomains.length).round();
      return '${AppConstants.domainLabels[d]} ≈ $pct%';
    }).join(' · ');
    return 'Solo i domini selezionati, nel loro rapporto ECO 2026 ($parts).';
  }

  Widget _buildGroupBanner() {
    final group = _group;
    return AppCard(
      backgroundColor: group != null
          ? AppColors.pmiGreenLight
          : AppColors.warningBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                group != null ? Icons.groups : Icons.group_off,
                color: group != null ? AppColors.pmiGreen : AppColors.warning,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group != null ? group.name : 'Nessun gruppo selezionato',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      group != null
                          ? '${group.usedQuestionIds.length} domande già proposte a questo gruppo'
                          : 'Le domande potrebbero ripetersi tra una sessione e l\'altra',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              if (group != null)
                IconButton(
                  tooltip: 'Reset domande gruppo',
                  icon: const Icon(Icons.restart_alt),
                  onPressed: group.usedQuestionIds.isEmpty
                      ? null
                      : _resetGroup,
                ),
              TextButton(
                onPressed: _changeGroup,
                child: Text(group != null ? 'Cambia' : 'Scegli gruppo'),
              ),
            ],
          ),
          if (group != null) ...[
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _adaptiveSelection,
              onChanged: (v) => setState(() => _adaptiveSelection = v),
              title: const Text('Selezione adattiva per dominio'),
              subtitle: const Text(
                'Pesca più domande dai domini dove questo gruppo è '
                'storicamente più debole (tra quelli selezionati sopra), '
                'invece dei pesi ECO fissi. Si attiva dalla 2ª sessione in '
                'poi.',
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Cambia modalità esame. In "Simulazione" non ha senso lasciare al
  /// trainer la scelta di quante domande o quali domini: dev'essere fedele
  /// all'esame reale, quindi si forzano 180 domande su tutti e tre i
  /// domini (proporzioni ECO 2026) — le card "Numero di domande" e
  /// "Domini" spariscono di conseguenza dall'interfaccia.
  void _setExamMode(String value) {
    setState(() {
      _examMode = value;
      if (value == 'simulation') {
        _questionCount = 180;
        _selectedDomains = {
          AppConstants.domainPeople,
          AppConstants.domainProcess,
          AppConstants.domainBusinessEnvironment,
        };
      }
    });
  }

  Widget _modeChip(String value, String title, String subtitle) {
    final selected = _examMode == value;
    return InkWell(
      onTap: () => _setExamMode(value),
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
