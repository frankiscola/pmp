import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../models/question.dart';

/// Multiple-Choice Single Response — il tipo più comune (~50% dell'esame).
///
/// Comportamento:
/// - Lo studente può cambiare selezione liberamente (blu neutro) finché non
///   preme "Conferma risposta": solo da quel momento si blocca davvero e
///   viene inviata al trainer.
/// - Solo quando [revealed] diventa true (il trainer ha premuto "Rivela
///   risposta") i colori cambiano a verde/rosso in base alla correttezza.
class SingleChoiceWidget extends StatefulWidget {
  final Question question;
  final bool revealed;

  /// Revisit di una domanda già risposta: blocca l'interazione senza
  /// mostrare corretto/sbagliato (quello resta esclusivo di [revealed]).
  final bool locked;
  final ValueChanged<String> onAnswered;

  const SingleChoiceWidget({
    super.key,
    required this.question,
    required this.onAnswered,
    this.revealed = false,
    this.locked = false,
  });

  @override
  State<SingleChoiceWidget> createState() => _SingleChoiceWidgetState();
}

class _SingleChoiceWidgetState extends State<SingleChoiceWidget> {
  String? _selectedId;
  bool _confirmed = false;

  void _select(String optionId) {
    // Dopo la rivelazione, il blocco per ripasso o la conferma, non si
    // cambia più. NOTA: qui NON si chiama più onAnswered ad ogni tap — solo
    // _confirm() lo fa, per essere coerenti con gli altri tipi di domanda
    // (dove "ha risposto" nella dashboard del trainer significa sempre "ha
    // confermato", mai "ha toccato qualcosa mentre ci pensava ancora").
    if (widget.revealed || widget.locked || _confirmed) return;
    setState(() => _selectedId = optionId);
  }

  void _confirm() {
    if (_selectedId == null) return;
    setState(() => _confirmed = true);
    widget.onAnswered(_selectedId!);
  }

  @override
  Widget build(BuildContext context) {
    final options = List<Map<String, dynamic>>.from(
      widget.question.options['options'] as List? ??
          widget.question.options['choices'] as List? ??
          (widget.question.options['hotspots'] as List?)
              ?.map((h) => {'id': h['id'], 'text': h['label']})
              .toList() ??
          [],
    );
    final correctId = widget.revealed
        ? (widget.question.correctAnswers as List).first as String
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...options.map((opt) {
        final id = opt['id'] as String;
        final text = opt['text'] as String;
        final isSelected = _selectedId == id;

        Color borderColor = AppColors.border;
        Color bgColor = AppColors.surface;
        Widget? trailingIcon;

        if (widget.revealed && correctId != null) {
          if (id == correctId) {
            borderColor = AppColors.success;
            bgColor = AppColors.successBg;
            trailingIcon = const Icon(
              Icons.check_circle,
              color: AppColors.success,
            );
          } else if (isSelected) {
            borderColor = AppColors.error;
            bgColor = AppColors.errorBg;
            trailingIcon = const Icon(Icons.cancel, color: AppColors.error);
          }
        } else if (isSelected) {
          // Selezionata ma non ancora rivelata: blu neutro, mai verde/rosso.
          borderColor = AppColors.pmiBlue;
          bgColor = AppColors.infoBg;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _select(id),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: borderColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? borderColor
                              : AppColors.textTertiary,
                          width: 2,
                        ),
                        color: isSelected ? borderColor : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(text, style: AppTextStyles.bodyLarge)),
                    if (trailingIcon != null) trailingIcon,
                  ],
                ),
              ),
            ),
          ),
        );
      }),
        if (!widget.revealed && !widget.locked) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: _confirmed
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Risposta confermata',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  )
                : TextButton(
                    onPressed: _selectedId == null ? null : _confirm,
                    child: const Text('Conferma risposta'),
                  ),
          ),
        ],
      ],
    );
  }
}
