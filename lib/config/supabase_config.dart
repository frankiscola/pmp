/// Credenziali di connessione a Supabase.
///
/// ATTENZIONE: sostituisci i due valori sotto con quelli del tuo progetto
/// (Project Settings → API su supabase.com). L'anonKey è pubblica per design
/// (protetta dalle policy di Row Level Security già presenti nello schema.sql),
/// ma è comunque buona norma non committarla su repository pubblici: valuta
/// di spostarla in variabili d'ambiente con --dart-define in un secondo momento.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://fqtbqtjufjzsrssxnqao.supabase.co';
  static const String publishableKey =
      'sb_publishable_dCDIHwBQ3xS7zJU6BtnAAA_Qu7JE6Km';
}
