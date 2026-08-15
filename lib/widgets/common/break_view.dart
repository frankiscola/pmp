import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Schermata mostrata allo studente quando il trainer mette l'esame in
/// pausa (Break). Sostituisce la domanda corrente finché il trainer non
/// riprende — a quel punto lo StreamBuilder che la mostra si ricostruisce
/// automaticamente e la domanda ricompare, il timer riparte da dove si
/// era fermato.
class BreakView extends StatelessWidget {
  const BreakView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.free_breakfast_outlined,
                  size: 72,
                  color: AppColors.pmiGreen,
                ),
                const SizedBox(height: 24),
                Text(
                  'Pausa',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: Colors.white,
                    fontSize: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'L\'esame è in pausa. Il timer è fermo:\nnessun tempo viene consumato.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Attendi che il trainer riprenda la sessione...',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
