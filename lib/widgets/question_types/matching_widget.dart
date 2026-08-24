import 'dart:math';

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../models/question.dart';

/// Palette di colori distinti per evidenziare visivamente ogni coppia
/// sinistra-destra una volta abbinata (prima della rivelazione).
/// Ogni voce è (colore bordo, colore sfondo chiaro).
const List<Color> _kPairBorderColors = [
  Color(0xFF0B6FB8), // blu PMI
  Color(0xFF6C5CE7), // viola
  Color(0xFFE8A33D), // ambra
  Color(0xFFD8433D), // rosso corallo
  Color(0xFF00A551), // verde PMI
  Color(0xFF00838F), // teal
  Color(0xFFAD1457), // magenta
  Color(0xFF8D6E63), // marrone
];

/// Matching / Enhanced Matching (drag & drop) — tap-to-match su mobile.
///
/// Lo studente abbina tutti i termini, poi preme "Conferma abbinamenti":
/// da quel momento gli abbinamenti si bloccano (blu neutro). I colori
/// corretto/sbagliato compaiono solo quando [revealed] diventa true.
class MatchingWidget extends StatefulWidget {
  final Question question;
  final bool revealed;
  final ValueChanged<Map<String, String>> onAnswered;

  const MatchingWidget({
    super.key,
    required this.question,
    required this.onAnswered,
    this.revealed = false,
  });

  /// Ordine "mescolato" della colonna destra per [question] — deterministico
  /// (stesso seed = stesso risultato ogni volta, per la stessa domanda) ma
  /// diverso dall'ordine grezzo salvato nel database.
  ///
  /// ESPOSTO COME STATICO e usato sia qui per il rendering interattivo sia
  /// da `live_dashboard_screen.dart` per il riepilogo testuale "Risposta
  /// corretta" mostrato al trainer: se le due logiche di shuffle
  /// divergessero, le lettere A/B/C/D nel riepilogo non corrisponderebbero
  /// più a quanto lo studente/trainer vede realmente a schermo — un'unica
  /// fonte di verità evita che possa succedere di nuovo.
  static List<Map<String, dynamic>> shuffledRight(Question question) {
    final right = List<Map<String, dynamic>>.from(
      question.options['right'] as List? ?? [],
    );
    final seed = question.id.hashCode;
    final rnd = Random(seed);
    final shuffled = List<Map<String, dynamic>>.from(right)..shuffle(rnd);

    var attempts = 0;
    while (_sameOrder(shuffled, right) && attempts < 5) {
      shuffled.shuffle(rnd);
      attempts++;
    }
    return shuffled;
  }

  static bool _sameOrder(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (a.length <= 1) return false; // niente da mescolare, non forzare
    for (var i = 0; i < a.length; i++) {
      if (a[i]['id'] != b[i]['id']) return false;
    }
    return true;
  }

  @override
  State<MatchingWidget> createState() => _MatchingWidgetState();
}

class _MatchingWidgetState extends State<MatchingWidget> {
  final Map<String, String> _matches = {}; // leftId -> rightId
  String? _activeLeftId;

  // Ordine mescolato della colonna destra, calcolato una sola volta per
  // domanda (in initState) così resta stabile durante i rebuild del widget.
  late List<Map<String, dynamic>> _rightShuffled;

  // Colore assegnato a ciascun leftId, in base alla sua posizione originale
  // nella colonna sinistra: resta coerente per tutta la domanda.
  final Map<String, Color> _leftPairColor = {};

  @override
  void initState() {
    super.initState();
    _setupForQuestion();
  }

  @override
  void didUpdateWidget(covariant MatchingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nuova domanda mostrata nello stesso widget instance: ricalcola.
    if (oldWidget.question.id != widget.question.id) {
      _matches.clear();
      _activeLeftId = null;
      _setupForQuestion();
    }
  }

  void _setupForQuestion() {
    final left = List<Map<String, dynamic>>.from(
      widget.question.options['left'] as List? ?? [],
    );

    _rightShuffled = MatchingWidget.shuffledRight(widget.question);

    _leftPairColor
      ..clear()
      ..addEntries(
        left.asMap().entries.map(
          (e) => MapEntry(
            e.value['id'] as String,
            _kPairBorderColors[e.key % _kPairBorderColors.length],
          ),
        ),
      );
  }

  void _selectLeft(String leftId) {
    if (widget.revealed) return; // dopo la rivelazione non si cambia più
    setState(() => _activeLeftId = _activeLeftId == leftId ? null : leftId);
  }

  void _selectRight(String rightId) {
    if (widget.revealed || _activeLeftId == null) return;
    setState(() {
      // NOTA: non rimuoviamo eventuali abbinamenti preesistenti verso
      // questo stesso rightId. Alcune domande (es. teoria di Herzberg, con
      // solo 2 categorie per 4 situazioni) richiedono che PIÙ termini di
      // sinistra puntino alla STESSA categoria a destra — è un abbinamento
      // "molti-a-uno" legittimo, non un errore. Rimuovere il match
      // precedente qui impediva fisicamente di completare quel tipo di
      // domanda (il pulsante "Conferma" restava bloccato per sempre).
      _matches[_activeLeftId!] = rightId;
      _activeLeftId = null;
    });
  }

  void _confirm() {
    widget.onAnswered(_matches);
  }

  @override
  Widget build(BuildContext context) {
    final left = List<Map<String, dynamic>>.from(
      widget.question.options['left'] as List? ?? [],
    );
    final right = _rightShuffled;
    final correctMap = widget.revealed
        ? Map<String, String>.from(widget.question.correctAnswers as Map)
        : <String, String>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.revealed
              ? 'Risultato:'
              : (_activeLeftId == null
                    ? 'Tocca un termine, poi la sua descrizione'
                    : 'Ora tocca la descrizione corrispondente'),
          style: AppTextStyles.label,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildColumn(left, isLeft: true, correctMap: correctMap),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildColumn(right, isLeft: false, correctMap: correctMap),
            ),
          ],
        ),
        if (!widget.revealed) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _matches.length == left.length ? _confirm : null,
              child: const Text('Conferma abbinamenti'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildColumn(
    List<Map<String, dynamic>> items, {
    required bool isLeft,
    required Map<String, String> correctMap,
  }) {
    return Column(
      children: items.map((item) {
        final id = item['id'] as String;
        final text = item['text'] as String;

        final isActive = isLeft && _activeLeftId == id;

        // Lato destro: quando più termini di sinistra puntano alla STESSA
        // categoria (molti-a-uno), serve considerarli TUTTI — non solo il
        // primo trovato — sia per lo stato "abbinato" sia, dopo il reveal,
        // per decidere se colorare la categoria di verde o rosso.
        final matchedLeftIds = isLeft
            ? const <String>[]
            : _matches.entries
                  .where((e) => e.value == id)
                  .map((e) => e.key)
                  .toList();
        final isMatched = isLeft
            ? _matches.containsKey(id)
            : matchedLeftIds.isNotEmpty;

        Color borderColor = AppColors.border;
        Color bgColor = AppColors.surface;

        if (widget.revealed) {
          if (isLeft) {
            final myMatchRight = _matches[id];
            final isCorrectPair =
                myMatchRight != null && correctMap[id] == myMatchRight;
            if (isMatched) {
              borderColor = isCorrectPair
                  ? AppColors.success
                  : AppColors.error;
              bgColor = isCorrectPair
                  ? AppColors.successBg
                  : AppColors.errorBg;
            }
          } else if (matchedLeftIds.isNotEmpty) {
            // Verde solo se OGNI termine abbinato a questa categoria è
            // stato assegnato correttamente; basta un solo errore tra i
            // vari termini condivisi per colorarla di rosso — altrimenti
            // uno studente vedrebbe verde anche con un abbinamento sbagliato
            // "nascosto" dietro uno corretto sulla stessa categoria.
            final allCorrect = matchedLeftIds.every(
              (lid) => correctMap[lid] == id,
            );
            borderColor = allCorrect ? AppColors.success : AppColors.error;
            bgColor = allCorrect ? AppColors.successBg : AppColors.errorBg;
          }
        } else if (isActive) {
          borderColor = AppColors.pmiGreen;
          bgColor = AppColors.pmiGreenLight;
        } else if (isMatched) {
          if (isLeft || matchedLeftIds.length == 1) {
            // Colore specifico della coppia (basato sul termine di
            // sinistra) così sinistra e destra abbinate condividono lo
            // stesso colore e si distinguono dalle altre coppie.
            final pairLeftId = isLeft ? id : matchedLeftIds.first;
            final pairColor = _leftPairColor[pairLeftId] ?? AppColors.pmiBlue;
            borderColor = pairColor;
            bgColor = pairColor.withValues(alpha: 0.12);
          } else {
            // Più di un termine condivide questa categoria: niente colore
            // di coppia univoco possibile, usa un evidenziato neutro.
            borderColor = AppColors.pmiBlue;
            bgColor = AppColors.pmiBlue.withValues(alpha: 0.12);
          }
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => isLeft ? _selectLeft(id) : _selectRight(id),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                constraints: const BoxConstraints(minHeight: 56),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: borderColor,
                    width: isActive ? 2 : 1,
                  ),
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  text,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: isMatched ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
