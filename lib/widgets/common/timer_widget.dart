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

  /// Quando true, il countdown si ferma esattamente dove si trova (nessun
  /// reset, nessun salto) e riparte da lì quando torna false. Usato per il
  /// Break: il trainer mette in pausa e il tempo residuo resta congelato.
  final bool paused;

  /// Quando true, [totalSeconds] è trattato come "verità corrente dal
  /// server" (non come una durata fissa impostata una volta sola): se un
  /// nuovo valore arriva — es. via realtime, dopo che la sessione è stata
  /// avviata — e si discosta troppo dal countdown locale, ci si riallinea
  /// invece di restare bloccati sul valore calcolato al primo mount.
  /// Usare SOLO per il timer "intero esame" (i cui secondi rimanenti sono
  /// ricalcolati ogni volta a partire da `started_at`/pause sul server):
  /// per il timer per-domanda [totalSeconds] è una durata fissa e va
  /// lasciato false, altrimenti ogni rebuild lo resetterebbe al massimo.
  final bool liveSync;

  const TimerWidget({
    super.key,
    required this.totalSeconds,
    required this.onExpired,
    this.compact = false,
    this.paused = false,
    this.liveSync = false,
  });

  @override
  State<TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget> {
  /// Sotto questa soglia una differenza tra il valore locale e quello del
  /// server è considerata normale drift (secondo in corso, piccola latenza
  /// di rete) e NON provoca un riallineamento — altrimenti il countdown
  /// "tremolerebbe" ad ogni rebuild.
  static const int _resyncThresholdSeconds = 2;

  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.totalSeconds;
    if (!widget.paused) _startTicking();
  }

  void _startTicking() {
    _timer?.cancel();
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
  void didUpdateWidget(covariant TimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paused && !oldWidget.paused) {
      // Il trainer ha appena premuto "Pausa": ferma il countdown sul
      // secondo esatto in cui si trova, senza toccare _remaining.
      _timer?.cancel();
    } else if (!widget.paused && oldWidget.paused) {
      // Ripresa dopo il Break: riparte da dove si era fermato.
      _startTicking();
    }

    // Riallineamento: se il valore in arrivo (autorevole, dal server) si
    // discosta troppo da quello che stiamo mostrando in locale — tipico
    // caso: al primo mount la sessione non aveva ancora tutti i dati
    // sincronizzati via realtime — ci allineiamo invece di restare
    // bloccati per sempre sul valore (sbagliato) del primo mount.
    if (widget.liveSync && !widget.paused) {
      final drift = (widget.totalSeconds - _remaining).abs();
      if (drift > _resyncThresholdSeconds) {
        setState(() => _remaining = widget.totalSeconds);
      }
    }
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
