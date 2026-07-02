import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/exam_session.dart';
import '../../models/participant.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../entry_screen.dart';

/// Classifica e analisi finale al termine della sessione: punteggio
/// per studente e suddivisione per dominio, utile per capire su cosa
/// la classe è più debole.
class ResultsScreen extends StatefulWidget {
  final ExamSession session;

  const ResultsScreen({super.key, required this.session});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  List<Participant> _participants = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final participants = await SupabaseService.instance.fetchParticipants(
      widget.session.id,
    );
    setState(() {
      _participants = participants;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Risultati finali')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text('Classifica', style: AppTextStyles.titleLarge),
                    const SizedBox(height: 16),
                    for (int i = 0; i < _participants.length; i++) ...[
                      _RankRow(rank: i + 1, participant: _participants[i]),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Torna alla home',
                      fullWidth: true,
                      variant: AppButtonVariant.outline,
                      onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const EntryScreen()),
                        (route) => false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final int rank;
  final Participant participant;

  const _RankRow({required this.rank, required this.participant});

  Color get _medalColor {
    switch (rank) {
      case 1:
        return const Color(0xFFD4AF37);
      case 2:
        return const Color(0xFFA7A7AD);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$rank',
              style: AppTextStyles.titleMedium.copyWith(color: _medalColor),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(participant.name, style: AppTextStyles.bodyLarge),
          ),
          Text(
            '${participant.score} pt',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.pmiGreen,
            ),
          ),
        ],
      ),
    );
  }
}
