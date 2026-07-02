import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../widgets/common/app_button.dart';
import 'trainer/trainer_login_screen.dart';
import 'student/join_screen.dart';

/// Prima schermata dell'app: scegli se sei il trainer o uno studente.
/// Stesso URL per entrambi i ruoli, come da architettura concordata.
class EntryScreen extends StatelessWidget {
  const EntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.pmiGreen,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.workspace_premium,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'PMP Simulazione Live',
                      style: AppTextStyles.displayMedium.copyWith(
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Preparazione all\'esame PMP · ECO 2026',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    AppButton(
                      label: 'Sono lo studente',
                      icon: Icons.smartphone,
                      fullWidth: true,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const JoinScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Sono il trainer',
                      icon: Icons.school,
                      variant: AppButtonVariant.outline,
                      foregroundColor: Colors.white,
                      fullWidth: true,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TrainerLoginScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
