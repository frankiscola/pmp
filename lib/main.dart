import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'screens/entry_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  runApp(const PmpQuizApp());
}

class PmpQuizApp extends StatelessWidget {
  const PmpQuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PMP Quiz Live',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const EntryScreen(),
    );
  }
}
