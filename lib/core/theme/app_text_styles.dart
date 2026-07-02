import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Tipografia dell'app — scala coerente ispirata alle Human Interface
/// Guidelines di Apple: poche taglie, pesi ben distinti, line-height
/// generoso per leggibilità su schermi piccoli (smartphone in aula).
class AppTextStyles {
  AppTextStyles._();

  static const String _fontFamily = 'SF Pro Display, Inter, -apple-system, sans-serif';

  // Display — usato solo per la schermata di ingresso / score finale
  static const TextStyle displayLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
    height: 1.1,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
    height: 1.15,
  );

  // Titoli di schermata / card
  static const TextStyle titleLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  // Testo domanda — deve essere il più leggibile di tutti
  static const TextStyle question = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 19,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // Corpo
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // Etichette, badge, bottoni
  static const TextStyle label = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.3,
  );

  static const TextStyle button = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
    height: 1.3,
  );

  // Numeri grandi (score, contatori live dashboard)
  static const TextStyle numericHero = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 56,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.0,
    letterSpacing: -1,
  );

  // Codice sessione (monospace, ben leggibile a distanza / su proiettore)
  static const TextStyle sessionCode = TextStyle(
    fontFamily: 'SF Mono, Menlo, monospace',
    fontSize: 44,
    fontWeight: FontWeight.w700,
    color: AppColors.textOnDark,
    letterSpacing: 6,
  );
}
