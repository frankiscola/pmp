import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../models/question.dart';

/// Point & Click — diagramma con punti cliccabili a coordinate reali.
/// Vedi single_choice_widget.dart per la spiegazione di [revealed]/[locked].
class PointAndClickWidget extends StatefulWidget {
  final Question question;
  final bool revealed;
  final bool locked;
  final String? initialAnswer;
  final ValueChanged<String> onAnswered;

  const PointAndClickWidget({
    super.key,
    required this.question,
    required this.onAnswered,
    this.revealed = false,
    this.locked = false,
    this.initialAnswer,
  });

  @override
  State<PointAndClickWidget> createState() => _PointAndClickWidgetState();
}

class _PointAndClickWidgetState extends State<PointAndClickWidget> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialAnswer;
  }

  bool get _interactive => !widget.revealed && !widget.locked;

  List<Map<String, dynamic>> get _hotspots => List<Map<String, dynamic>>.from(
        widget.question.options['hotspots'] as List? ?? [],
      );

  String? get _correctId {
    if (!widget.revealed) return null;
    final correct = widget.question.correctAnswers;
    if (correct is List && correct.isNotEmpty) return correct.first as String;
    return null;
  }

  void _handleTap(Offset localPosition, Size size) {
    if (!_interactive) return;
    const hitRadius = 34.0;
    String? tappedId;
    double bestDistance = double.infinity;
    for (final h in _hotspots) {
      final hx = (h['x'] as num).toDouble() * size.width;
      final hy = (h['y'] as num).toDouble() * size.height;
      final distance = (localPosition - Offset(hx, hy)).distance;
      if (distance <= hitRadius && distance < bestDistance) {
        bestDistance = distance;
        tappedId = h['id'] as String;
      }
    }
    if (tappedId != null) {
      setState(() => _selectedId = tappedId);
      widget.onAnswered(tappedId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final description = widget.question.options['imageDescription'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.locked && !widget.revealed)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(Icons.lock_outline, size: 14, color: AppColors.textTertiary),
                SizedBox(width: 6),
                Text('Domanda già risposta — non modificabile', style: AppTextStyles.caption),
              ],
            ),
          ),
        if (description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(description, style: AppTextStyles.caption),
          ),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                onTapUp: (details) => _handleTap(details.localPosition, size),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: CustomPaint(
                    size: size,
                    painter: _HotspotPainter(
                      hotspots: _hotspots,
                      selectedId: _selectedId,
                      correctId: _correctId,
                      revealed: widget.revealed,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.revealed
              ? 'Risultato'
              : (widget.locked
                  ? ' '
                  : (_selectedId == null
                      ? 'Tocca il punto corretto nel diagramma'
                      : 'Selezionato — tocca un altro punto per cambiare')),
          style: AppTextStyles.label,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _HotspotPainter extends CustomPainter {
  final List<Map<String, dynamic>> hotspots;
  final String? selectedId;
  final String? correctId;
  final bool revealed;

  _HotspotPainter({
    required this.hotspots,
    required this.selectedId,
    required this.correctId,
    required this.revealed,
  });

  static const double _radius = 28;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final guidePaint = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1.5;
    for (final h in hotspots) {
      final point = _pointFor(h, size);
      canvas.drawLine(center, point, guidePaint);
    }

    final centerPaint = Paint()..color = AppColors.pmiNavy;
    canvas.drawCircle(center, 7, centerPaint);

    for (final h in hotspots) {
      final id = h['id'] as String;
      final label = h['label'] as String? ?? '';
      final point = _pointFor(h, size);

      Color fillColor = Colors.white;
      Color borderColor = AppColors.pmiBlue;

      if (revealed && correctId != null) {
        if (id == correctId) {
          fillColor = AppColors.successBg;
          borderColor = AppColors.success;
        } else if (id == selectedId) {
          fillColor = AppColors.errorBg;
          borderColor = AppColors.error;
        } else {
          borderColor = AppColors.border;
        }
      } else if (id == selectedId) {
        fillColor = AppColors.infoBg;
        borderColor = AppColors.pmiBlue;
      } else {
        borderColor = AppColors.textTertiary;
      }

      final circlePaint = Paint()..color = fillColor;
      final borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = id == selectedId ? 3 : 2;

      canvas.drawCircle(point, _radius, circlePaint);
      canvas.drawCircle(point, _radius, borderPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 100);

      final labelY = point.dy < size.height / 2
          ? point.dy - _radius - textPainter.height - 4
          : point.dy + _radius + 4;
      final labelOffset = Offset(
        (point.dx - textPainter.width / 2).clamp(0, size.width - textPainter.width),
        labelY.clamp(0, size.height - textPainter.height),
      );
      textPainter.paint(canvas, labelOffset);

      if (revealed && id == correctId) {
        final checkPainter = TextPainter(
          text: const TextSpan(
            text: '✓',
            style: TextStyle(color: AppColors.success, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        checkPainter.paint(
          canvas,
          point - Offset(checkPainter.width / 2, checkPainter.height / 2),
        );
      }
    }
  }

  Offset _pointFor(Map<String, dynamic> hotspot, Size size) {
    return Offset(
      (hotspot['x'] as num).toDouble() * size.width,
      (hotspot['y'] as num).toDouble() * size.height,
    );
  }

  @override
  bool shouldRepaint(covariant _HotspotPainter oldDelegate) {
    return oldDelegate.selectedId != selectedId ||
        oldDelegate.revealed != revealed ||
        oldDelegate.correctId != correctId;
  }
}
