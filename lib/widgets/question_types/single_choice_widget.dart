import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../models/question.dart';

/// Multiple-Choice Single Response — il tipo più comune (~50% dell'esame).
///
/// Comportamento:
/// - Al primo tap la scelta si seleziona in blu neutro — nessun giudizio di
///   correttezza ancora. Può essere cambiata liberamente finché non arriva
///   [revealed] oppure [locked].
/// - [revealed]=true (il trainer ha premuto "Rivela risposta"): colori
///   verde/rosso in base alla correttezza, interazione disabilitata.
/// - [locked]=true (il trainer è tornato a una domanda già risposta in
///   precedenza): interazione disabilitata, ma [initialAnswer] viene
///   mostrata selezionata in blu, senza rivelare corretto/sbagliato.
class SingleChoiceWidget extends StatefulWidget {
  final Question question;
  final bool revealed;
  final bool locked;
  final String? initialAnswer;
  final ValueChanged<String> onAnswered;

  const SingleChoiceWidget({
    super.key,
    required this.question,
    required this.onAnswered,
    this.revealed = false,
    this.locked = false,
    this.initialAnswer,
  });

  @override
  State<SingleChoiceWidget> createState() => _SingleChoiceWidgetState();
}

class _SingleChoiceWidgetState extends State<SingleChoiceWidget> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialAnswer;
  }

  void _select(String optionId) {
    if (widget.revealed || widget.locked) return;
    setState(() => _selectedId = optionId);
    widget.onAnswered(optionId);
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
    final interactive = !widget.revealed && !widget.locked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.locked && !widget.revealed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 6),
                Text(
                  'Domanda già risposta — non modificabile',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
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
              trailingIcon = const Icon(Icons.check_circle, color: AppColors.success);
            } else if (isSelected) {
              borderColor = AppColors.error;
              bgColor = AppColors.errorBg;
              trailingIcon = const Icon(Icons.cancel, color: AppColors.error);
            }
          } else if (isSelected) {
            // Selezionata ma non ancora rivelata (o bloccata su revisit):
            // blu neutro, mai verde/rosso.
            borderColor = AppColors.pmiBlue;
            bgColor = AppColors.infoBg;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: interactive ? () => _select(id) : null,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                child: Opacity(
                  opacity: widget.locked && !widget.revealed && !isSelected ? 0.6 : 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? borderColor : AppColors.textTertiary,
                              width: 2,
                            ),
                            color: isSelected ? borderColor : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
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
            ),
          );
        }),
      ],
    );
  }
}
