import 'dart:convert';

import 'package:flutter/foundation.dart';

class SupabaseConfigurationException implements Exception {
  const SupabaseConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef SupabaseInitializer = Future<void> Function({
  required String url,
  required String publishableKey,
});

class SupabaseConfig {
  const SupabaseConfig({
    required this.url,
    required this.publishableKey,
    this.environment = 'desenvolvimento',
  });

  static const current = SupabaseConfig(
    url: String.fromEnvironment('SUPABASE_URL'),
    publishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    environment: String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'desenvolvimento',
    ),
  );

  static const webAuthCallback = String.fromEnvironment(
    'WEB_AUTH_CALLBACK',
    defaultValue: 'https://prova-social.pages.dev/app/',
  );

  final String url;
  final String publishableKey;
  final String environment;

  bool get hasValidUrl {
    final parsedUrl = Uri.tryParse(url);
    return parsedUrl != null &&
        parsedUrl.scheme == 'https' &&
        parsedUrl.host.isNotEmpty &&
        parsedUrl.userInfo.isEmpty &&
        parsedUrl.query.isEmpty &&
        parsedUrl.fragment.isEmpty;
  }

  bool get hasExpectedClientKey => _isPublishableKey(publishableKey);

  /// Safe to log: contains status flags only, never URL or key values.
  Map<String, bool> get diagnostics => {
    'urlPresent': url.trim().isNotEmpty,
    'urlValid': hasValidUrl,
    'publishableKeyPresent': publishableKey.trim().isNotEmpty,
    'publishableKeyPrefixExpected': hasExpectedClientKey,
  };

  void validate() {
    _logConfigurationStatus(this);
    if (url.trim().isEmpty || publishableKey.trim().isEmpty) {
      throw SupabaseConfigurationException(
        'Configuração do Supabase ausente no build de $environment. '
        'No desenvolvimento local, configure .env.supabase.json e use '
        './tool/flutter_with_supabase.sh run.',
      );
    }
    if (!hasValidUrl) {
      throw SupabaseConfigurationException(
        'SUPABASE_URL inválida no build de $environment. '
        'A URL deve ser HTTPS e não pode conter credenciais.',
      );
    }
    if (!hasExpectedClientKey) {
      throw SupabaseConfigurationException(
        'SUPABASE_PUBLISHABLE_KEY inválida no build de $environment. '
        'Use uma chave sb_publishable_ ou uma chave anon legada válida.',
      );
    }
  }

  static bool _isPublishableKey(String key) {
    if (key.startsWith('sb_publishable_')) return key.length > 15;

    // Legacy anon keys are JWTs and remain supported by Supabase. Reject
    // service_role JWTs by checking the role claim without logging the token.
    final segments = key.split('.');
    if (segments.length != 3 || !segments[0].startsWith('eyJ')) return false;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
      );
      return payload is Map<String, dynamic> && payload['role'] == 'anon';
    } on FormatException {
      return false;
    }
  }
}

Future<void> initializeSupabase({
  required SupabaseConfig config,
  required SupabaseInitializer initialize,
  Future<void> Function()? beforeSupabaseInitialize,
}) async {
  config.validate();
  await beforeSupabaseInitialize?.call();
  try {
    await initialize(url: config.url, publishableKey: config.publishableKey);
  } catch (error) {
    debugPrint(
      '[SUPABASE_CONFIG] Supabase inicializado: NÃO (${error.runtimeType})',
    );
    rethrow;
  }
  debugPrint('[SUPABASE_CONFIG] Supabase inicializado: SIM');
}

void _logConfigurationStatus(SupabaseConfig config) {
  final status = config.diagnostics;
  debugPrint(
    '[SUPABASE_CONFIG] URL presente: ${_yesNo(status['urlPresent'])}; '
    'URL válida: ${_yesNo(status['urlValid'])}; '
    'publishable key presente: ${_yesNo(status['publishableKeyPresent'])}; '
    'prefixo esperado: ${_yesNo(status['publishableKeyPrefixExpected'])}',
  );
}

String _yesNo(bool? value) => value == true ? 'SIM' : 'NÃO';
