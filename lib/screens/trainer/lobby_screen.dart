import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/exam_session.dart';
import '../../models/participant.dart';
import '../../services/realtime_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import 'live_dashboard_screen.dart';

/// Lobby del trainer: mostra codice sessione + QR, e la lista di
/// studenti che si connettono in tempo reale, prima di iniziare.
class LobbyScreen extends StatelessWidget {
  final ExamSession session;

  const LobbyScreen({super.key, required this.session});

  Future<void> _start(BuildContext context) async {
    await SupabaseService.instance.startSession(session.id);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LiveDashboardScreen(session: session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final joinUrl = 'https://pmpquiz.app/join?code=${session.code}';

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'Gli studenti si connettono su',
                    style: AppTextStyles.bodyLarge.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text('pmpquiz.app/join', style: AppTextStyles.titleLarge.copyWith(color: Colors.white)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: QrImageView(data: joinUrl, size: 180),
                      ),
                      const SizedBox(width: 32),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('oppure inserisci il codice', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70)),
                          const SizedBox(height: 4),
                          Text(session.code, style: AppTextStyles.sessionCode),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Expanded(
                    child: StreamBuilder<List<Participant>>(
                      stream: RealtimeService.instance.watchParticipants(session.id),
                      builder: (context, snapshot) {
                        final participants = snapshot.data ?? [];
                        return Column(
                          children: [
                            Text(
                              '${participants.length} connessi',
                              style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: GridView.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 2.6,
                                ),
                                itemCount: participants.length,
                                itemBuilder: (context, i) {
                                  return AppCard(
                                    backgroundColor: AppColors.surface,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.person, color: AppColors.pmiGreen, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            participants[i].name,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Inizia sessione',
                    icon: Icons.play_arrow,
                    fullWidth: true,
                    onPressed: () => _start(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
