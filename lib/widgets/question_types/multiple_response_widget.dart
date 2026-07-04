import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../models/question.dart';

/// Multiple-Response Questions (~20% dell'esame) — checkbox multipli.
///
/// Lo studente seleziona liberamente finché non preme "Conferma risposta":
/// da quel momento la selezione si blocca (blu neutro). I colori
/// corretto/sbagliato compaiono solo quando [revealed] diventa true.
class MultipleResponseWidget extends StatefulWidget {
  final Question question;
  final bool revealed;
  final ValueChanged<List<String>> onAnswered;

  const MultipleResponseWidget({
    super.key,
    required this.question,
    required this.onAnswered,
    this.revealed = false,
  });

  @override
  State<MultipleResponseWidget> createState() => _MultipleResponseWidgetState();
}

class _MultipleResponseWidgetState extends State<MultipleResponseWidget> {
  final Set<String> _selected = {};

  void _toggle(String id) {
    if (widget.revealed) return; // dopo la rivelazione non si cambia più
    setState(() {
      _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    });
  }

  void _confirm() {
    widget.onAnswered(_selected.toList());
  }

  @override
  Widget build(BuildContext context) {
    final options = List<Map<String, dynamic>>.from(
      widget.question.options['options'] as List? ?? [],
    );
    final correctSet = widget.revealed
        ? Set<String>.from(widget.question.correctAnswers as List)
        : <String>{};
    final requiredCount = (widget.question.correctAnswers as List).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Seleziona $requiredCount risposte', style: AppTextStyles.label),
        const SizedBox(height: 12),
        ...options.map((opt) {
          final id = opt['id'] as String;
          final text = opt['text'] as String;
          final isSelected = _selected.contains(id);

          Color borderColor = AppColors.border;
          Color bgColor = AppColors.surface;
          Widget? trailingIcon;

          if (widget.revealed) {
            if (correctSet.contains(id)) {
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
            borderColor = AppColors.pmiBlue;
            bgColor = AppColors.infoBg;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _toggle(id),
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
                      Icon(
                        isSelected
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color: isSelected
                            ? borderColor
                            : AppColors.textTertiary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(text, style: AppTextStyles.bodyLarge),
                      ),
                      if (trailingIcon != null) trailingIcon,
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        if (!widget.revealed) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _selected.isEmpty ? null : _confirm,
              child: const Text('Conferma risposta'),
            ),
          ),
        ],
      ],
    );
  }
}
