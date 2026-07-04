import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../models/question.dart';

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

  @override
  State<MatchingWidget> createState() => _MatchingWidgetState();
}

class _MatchingWidgetState extends State<MatchingWidget> {
  final Map<String, String> _matches = {}; // leftId -> rightId
  String? _activeLeftId;

  void _selectLeft(String leftId) {
    if (widget.revealed) return; // dopo la rivelazione non si cambia più
    setState(() => _activeLeftId = _activeLeftId == leftId ? null : leftId);
  }

  void _selectRight(String rightId) {
    if (widget.revealed || _activeLeftId == null) return;
    setState(() {
      _matches.removeWhere((_, v) => v == rightId);
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
    final right = List<Map<String, dynamic>>.from(
      widget.question.options['right'] as List? ?? [],
    );
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
        final matchedLeftId = isLeft
            ? null
            : _matches.entries
                  .firstWhere(
                    (e) => e.value == id,
                    orElse: () => const MapEntry('', ''),
                  )
                  .key;
        final isMatched = isLeft
            ? _matches.containsKey(id)
            : matchedLeftId!.isNotEmpty;

        Color borderColor = AppColors.border;
        Color bgColor = AppColors.surface;

        if (widget.revealed) {
          final myMatchRight = isLeft ? _matches[id] : null;
          final isCorrectPair = isLeft
              ? (myMatchRight != null && correctMap[id] == myMatchRight)
              : (matchedLeftId!.isNotEmpty && correctMap[matchedLeftId] == id);
          if (isMatched) {
            borderColor = isCorrectPair ? AppColors.success : AppColors.error;
            bgColor = isCorrectPair ? AppColors.successBg : AppColors.errorBg;
          }
        } else if (isActive) {
          borderColor = AppColors.pmiGreen;
          bgColor = AppColors.pmiGreenLight;
        } else if (isMatched) {
          borderColor = AppColors.pmiBlue;
          bgColor = AppColors.infoBg;
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
