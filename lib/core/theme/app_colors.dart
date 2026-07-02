import 'package:flutter/material.dart';

/// Design system colori — PMP Quiz App
/// Palette ispirata al brand PMI (verde primario) con l'attenzione
/// al contrasto e alla gerarchia visiva tipica delle app Apple-style:
/// pochi colori, ognuno con un significato univoco, mai decorativo.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------
  // BRAND — PMI Green come colore primario, il resto costruito attorno
  // ---------------------------------------------------------------------
  static const Color pmiGreen = Color(0xFF00A551);
  static const Color pmiGreenDark = Color(0xFF00753A);
  static const Color pmiGreenLight = Color(0xFFE3F7EC);

  static const Color pmiNavy = Color(0xFF1B2A4A);   // testo primario, header
  static const Color pmiBlue = Color(0xFF0B6FB8);   // link, azioni secondarie

  // ---------------------------------------------------------------------
  // SEMANTIC — coerenti in tutta l'app: stesso significato ovunque
  // ---------------------------------------------------------------------
  static const Color success = pmiGreen;
  static const Color successBg = pmiGreenLight;

  static const Color error = Color(0xFFD8433D);
  static const Color errorBg = Color(0xFFFCEAE9);

  static const Color warning = Color(0xFFE8A33D);
  static const Color warningBg = Color(0xFFFDF3E3);

  static const Color info = pmiBlue;
  static const Color infoBg = Color(0xFFE8F3FB);

  // ---------------------------------------------------------------------
  // NEUTRALS — scala di grigi per testo, bordi, superfici
  // ---------------------------------------------------------------------
  static const Color textPrimary = Color(0xFF1B1F27);
  static const Color textSecondary = Color(0xFF5C6370);
  static const Color textTertiary = Color(0xFF9AA1AC);
  static const Color textOnDark = Color(0xFFFFFFFF);

  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF7F8FA);
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  static const Color border = Color(0xFFE4E7EB);
  static const Color divider = Color(0xFFEDEEF1);

  static const Color background = Color(0xFFF4F5F7);
  static const Color backgroundDark = pmiNavy;

  // ---------------------------------------------------------------------
  // DOMAIN COLORS — un colore distintivo per ciascuno dei 3 domini ECO
  // usati coerentemente in badge, grafici, dashboard live
  // ---------------------------------------------------------------------
  static const Color domainPeople = Color(0xFF6C5CE7);      // viola
  static const Color domainProcess = pmiBlue;                // blu PMI
  static const Color domainBusinessEnv = Color(0xFFE8A33D);  // ambra

  static Color domainColor(String domain) {
    switch (domain) {
      case 'people':
        return domainPeople;
      case 'process':
        return domainProcess;
      case 'business_environment':
        return domainBusinessEnv;
      default:
        return textSecondary;
    }
  }

  // ---------------------------------------------------------------------
  // GRADIENTS — usati con parsimonia: solo header trainer e schermata join
  // ---------------------------------------------------------------------
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [pmiGreen, pmiGreenDark],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [pmiNavy, Color(0xFF0F1830)],
  );
}
