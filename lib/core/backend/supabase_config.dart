abstract final class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
  );

  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static const webAuthCallback = String.fromEnvironment(
    'WEB_AUTH_CALLBACK',
    defaultValue: 'https://prova-social.pages.dev/app/',
  );

  static void validate() {
    if (url.isEmpty || publishableKey.isEmpty) {
      throw StateError(
        'Supabase não configurado. Informe SUPABASE_URL e '
        'SUPABASE_PUBLISHABLE_KEY usando --dart-define.',
      );
    }
  }
}
