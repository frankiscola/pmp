import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Countdown circolare compatto — usato sia per il timer per-domanda
/// sia per il timer totale dell'esame. Cambia colore quando il tempo
/// sta per scadere (ultimi 20%), senza essere ansiogeno: solo un
/// sottile passaggio verso l'ambra, mai lampeggi aggressivi.
class TimerWidget extends StatefulWidget {
  final int totalSeconds;
  final VoidCallback onExpired;
  final bool compact;

  const TimerWidget({
    super.key,
    required this.totalSeconds,
    required this.onExpired,
    this.compact = false,
  });

  @override
  State<TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.totalSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _remaining--;
      });
      if (_remaining <= 0) {
        t.cancel();
        widget.onExpired();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _label {
    final minutes = _remaining ~/ 60;
    final seconds = _remaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final fraction = (_remaining / widget.totalSeconds).clamp(0.0, 1.0);
    final isLow = fraction < 0.2;
    final color = isLow ? AppColors.warning : AppColors.pmiGreen;

    final size = widget.compact ? 40.0 : 64.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: fraction,
              strokeWidth: widget.compact ? 3 : 4,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text(
            _label,
            style: (widget.compact ? AppTextStyles.caption : AppTextStyles.bodyMedium)
                .copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
