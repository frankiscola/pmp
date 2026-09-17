import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../models/question.dart';

/// Pull-down List — testo con lacune da completare scegliendo da un menu
/// a tendina. Dopo "Conferma risposta" le scelte si bloccano (blu neutro);
/// i colori corretto/sbagliato compaiono solo quando [revealed] è true.
class PulldownWidget extends StatefulWidget {
  final Question question;
  final bool revealed;
  final ValueChanged<Map<String, String>> onAnswered;

  const PulldownWidget({
    super.key,
    required this.question,
    required this.onAnswered,
    this.revealed = false,
  });

  @override
  State<PulldownWidget> createState() => _PulldownWidgetState();
}

class _PulldownWidgetState extends State<PulldownWidget> {
  final Map<String, String> _selections = {};

  void _confirm() {
    widget.onAnswered(_selections);
  }

  @override
  Widget build(BuildContext context) {
    final blanks = List<Map<String, dynamic>>.from(
      widget.question.options['blanks'] as List? ?? [],
    );
    final correctMap = widget.revealed
        ? Map<String, String>.from(widget.question.correctAnswers as Map)
        : <String, String>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final blank in blanks) ...[
          _buildDropdownRow(blank, correctMap),
          const SizedBox(height: 14),
        ],
        if (!widget.revealed) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _selections.length == blanks.length ? _confirm : null,
              child: const Text('Conferma risposta'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDropdownRow(
    Map<String, dynamic> blank,
    Map<String, String> correctMap,
  ) {
    final id = blank['id'] as String;
    final label = blank['label'] as String? ?? id;
    final choices = List<String>.from(blank['choices'] as List);
    final selected = _selections[id];

    Color borderColor = AppColors.border;
    if (widget.revealed) {
      borderColor = selected == correctMap[id]
          ? AppColors.success
          : AppColors.error;
    } else if (selected != null) {
      borderColor = AppColors.pmiBlue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: selected != null ? 2 : 1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        color: AppColors.surface,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.bodyLarge)),
          DropdownButton<String>(
            value: selected,
            hint: const Text('Scegli...'),
            underline: const SizedBox(),
            items: choices
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: widget.revealed
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _selections[id] = value);
                  },
          ),
        ],
      ),
    );
  }
}
