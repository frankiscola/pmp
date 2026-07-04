import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common/app_button.dart';
import 'waiting_screen.dart';

/// Schermata di ingresso studente: inserisce il codice sessione
/// (es. "PMP-7823") e il proprio nome. Nessuna registrazione richiesta.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _join() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await SupabaseService.instance.fetchSessionByCode(
        _codeController.text.trim(),
      );
      if (session == null) {
        setState(() => _error = 'Codice non valido. Controlla e riprova.');
        return;
      }
      final participant = await SupabaseService.instance.joinSession(
        session.id,
        _nameController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              WaitingScreen(session: session, participant: participant),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Qualcosa è andato storto. Riprova.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canJoin =
        _codeController.text.trim().isNotEmpty &&
        _nameController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Entra nel quiz')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Codice sessione', style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppTextStyles.titleLarge.copyWith(letterSpacing: 4),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: '738492',
                    filled: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),
                Text('Il tuo nome', style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'Nome e cognome',
                    filled: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => canJoin ? _join() : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                AppButton(
                  label: 'Entra',
                  fullWidth: true,
                  loading: _loading,
                  onPressed: canJoin ? _join : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
