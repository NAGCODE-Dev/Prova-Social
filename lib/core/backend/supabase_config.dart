abstract final class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://kpjcwpdnzsbgypdefrpz.supabase.co',
  );

  // Chave pública: pode ficar no aplicativo. Nunca use service_role no cliente.
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_M2-eynfYJ6JmSef8Azq7oA_rFq4YiZv',
  );
}
