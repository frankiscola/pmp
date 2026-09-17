import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../models/question.dart';

/// Multiple-Response Questions (~20% dell'esame) — checkbox multipli.
/// Vedi single_choice_widget.dart per la spiegazione di [revealed]/[locked].
class MultipleResponseWidget extends StatefulWidget {
  final Question question;
  final bool revealed;
  final bool locked;
  final List<String>? initialAnswer;
  final ValueChanged<List<String>> onAnswered;

  const MultipleResponseWidget({
    super.key,
    required this.question,
    required this.onAnswered,
    this.revealed = false,
    this.locked = false,
    this.initialAnswer,
  });

  @override
  State<MultipleResponseWidget> createState() => _MultipleResponseWidgetState();
}

class _MultipleResponseWidgetState extends State<MultipleResponseWidget> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initialAnswer ?? const []);
  }

  bool get _interactive => !widget.revealed && !widget.locked;

  void _toggle(String id) {
    if (!_interactive) return;
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
        if (widget.locked && !widget.revealed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 6),
                Text('Domanda già risposta — non modificabile', style: AppTextStyles.caption),
              ],
            ),
          )
        else
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
              trailingIcon = const Icon(Icons.check_circle, color: AppColors.success);
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
                onTap: _interactive ? () => _toggle(id) : null,
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
                        Icon(
                          isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                          color: isSelected ? borderColor : AppColors.textTertiary,
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
        if (_interactive) ...[
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
