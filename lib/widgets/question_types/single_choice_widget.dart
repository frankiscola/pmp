import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../models/question.dart';

/// Multiple-Choice Single Response — il tipo più comune (~50% dell'esame).
///
/// Comportamento:
/// - Al primo tap la scelta si BLOCCA (non modificabile) e appare in blu
///   neutro — nessun giudizio di correttezza ancora.
/// - Solo quando [revealed] diventa true (il trainer ha premuto "Rivela
///   risposta") i colori cambiano a verde/rosso in base alla correttezza.
class SingleChoiceWidget extends StatefulWidget {
  final Question question;
  final bool revealed;
  final ValueChanged<String> onAnswered;

  const SingleChoiceWidget({
    super.key,
    required this.question,
    required this.onAnswered,
    this.revealed = false,
  });

  @override
  State<SingleChoiceWidget> createState() => _SingleChoiceWidgetState();
}

class _SingleChoiceWidgetState extends State<SingleChoiceWidget> {
  String? _selectedId;

  void _select(String optionId) {
    if (widget.revealed) return; // dopo la rivelazione non si cambia più
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: options.map((opt) {
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
      }).toList(),
    );
  }
}
