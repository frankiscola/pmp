import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/exam_session.dart';
import '../../models/participant.dart';
import '../../services/realtime_service.dart';
import 'question_screen.dart';

/// Lobby lato studente: attende che il trainer prema "Inizia sessione".
/// Ascolta lo stato della sessione via realtime e naviga automaticamente
/// alla prima domanda non appena lo stato passa a "running".
class WaitingScreen extends StatelessWidget {
  final ExamSession session;
  final Participant participant;

  const WaitingScreen({super.key, required this.session, required this.participant});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ExamSession?>(
      stream: RealtimeService.instance.watchSession(session.id),
      initialData: session,
      builder: (context, snapshot) {
        final current = snapshot.data ?? session;

        if (current.status == AppConstants.sessionRunning) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => QuestionScreen(session: current, participant: participant),
              ),
            );
          });
        }

        return Scaffold(
          backgroundColor: AppColors.backgroundDark,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.pmiGreen),
                  const SizedBox(height: 32),
                  Text(
                    'Sei dentro, ${participant.name.split(' ').first}!',
                    style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'In attesa che il trainer inizi la sessione...',
                    style: AppTextStyles.bodyLarge.copyWith(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
