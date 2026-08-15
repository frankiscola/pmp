import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../models/group.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import 'trainer_home_screen.dart';

/// Prima schermata dopo il login trainer: scegli con quale gruppo di
/// studenti stai lavorando oggi (o creane uno nuovo). Serve a tenere
/// traccia di quali domande sono già state proposte a quel gruppo nelle
/// giornate precedenti, per non ripeterle.
class GroupSelectionScreen extends StatefulWidget {
  const GroupSelectionScreen({super.key});

  @override
  State<GroupSelectionScreen> createState() => _GroupSelectionScreenState();
}

class _GroupSelectionScreenState extends State<GroupSelectionScreen> {
  late Future<List<Group>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _groupsFuture = SupabaseService.instance.fetchGroups();
  }

  void _refresh() {
    setState(() {
      _groupsFuture = SupabaseService.instance.fetchGroups();
    });
  }

  void _openHome(Group? group) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TrainerHomeScreen(group: group)),
    );
  }

  Future<void> _createGroup() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuovo gruppo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nome del gruppo',
            hintText: 'Es. "Corso PMP Gennaio 2026"',
          ),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Crea'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      final group = await SupabaseService.instance.createGroup(name.trim());
      if (!mounted) return;
      _openHome(group);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }

  Future<void> _confirmReset(Group group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset domande gruppo'),
        content: Text(
          'Vuoi svuotare lo storico delle ${group.usedQuestionIds.length} '
          'domande già proposte a "${group.name}"?\n\n'
          'Alla prossima sessione tutte le domande torneranno disponibili '
          'per questo gruppo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await SupabaseService.instance.resetGroupQuestions(group.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Storico di "${group.name}" azzerato.')),
    );
    _refresh();
  }

  Future<void> _confirmDelete(Group group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Elimina gruppo'),
        content: Text('Vuoi eliminare definitivamente "${group.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await SupabaseService.instance.deleteGroup(group.id);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Con chi lavori oggi?'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => SupabaseService.instance.trainerSignOut(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: FutureBuilder<List<Group>>(
            future: _groupsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final groups = snapshot.data ?? [];
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Seleziona il gruppo con cui stai facendo la sessione '
                    'di oggi: le domande già proposte a quel gruppo nelle '
                    'giornate precedenti non verranno riproposte.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'Nuovo gruppo',
                    icon: Icons.group_add,
                    fullWidth: true,
                    onPressed: _createGroup,
                  ),
                  const SizedBox(height: 24),
                  if (groups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Non hai ancora nessun gruppo salvato.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else ...[
                    const Text(
                      'Gruppi esistenti',
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    ...groups.map(
                      (group) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          onTap: () => _openHome(group),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.pmiGreenLight,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMedium,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.groups,
                                  color: AppColors.pmiGreen,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      group.name,
                                      style: AppTextStyles.bodyLarge
                                          .copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${group.usedQuestionIds.length} '
                                      'domande già proposte',
                                      style: AppTextStyles.caption,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Reset domande',
                                icon: const Icon(Icons.restart_alt),
                                onPressed: group.usedQuestionIds.isEmpty
                                    ? null
                                    : () => _confirmReset(group),
                              ),
                              IconButton(
                                tooltip: 'Elimina gruppo',
                                icon: const Icon(Icons.delete_outline),
                                color: AppColors.error,
                                onPressed: () => _confirmDelete(group),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => _openHome(null),
                      child: const Text(
                        'Continua senza gruppo (non tracciare le domande)',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
