import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/backend/supabase_config.dart';

void main() {
  const url = 'https://project-ref.supabase.co';
  const key = 'sb_publishable_test_key';

  test('valid client configuration initializes with publishableKey', () async {
    final config = SupabaseConfig(url: url, publishableKey: key);
    var receivedUrl = '';
    var receivedKey = '';

    await initializeSupabase(
      config: config,
      initialize: ({required url, required publishableKey}) async {
        receivedUrl = url;
        receivedKey = publishableKey;
      },
    );

    expect(receivedUrl, url);
    expect(receivedKey, key);
  });

  test('PDF runtime initializes before the Supabase client', () async {
    final steps = <String>[];
    await initializeSupabase(
      config: const SupabaseConfig(url: url, publishableKey: key),
      beforeSupabaseInitialize: () async => steps.add('pdfrx'),
      initialize: ({required url, required publishableKey}) async {
        steps.add('supabase');
      },
    );
    expect(steps, ['pdfrx', 'supabase']);
  });

  test('missing URL is reported as missing build configuration', () {
    const config = SupabaseConfig(url: '', publishableKey: key);
    expect(
      config.validate,
      throwsA(
        isA<SupabaseConfigurationException>().having(
          (error) => error.message,
          'message',
          contains('ausente no build de desenvolvimento'),
        ),
      ),
    );
  });

  test('missing publishable key is reported without exposing values', () {
    const config = SupabaseConfig(url: url, publishableKey: '');
    expect(config.validate, throwsA(isA<SupabaseConfigurationException>()));
  });

  test('invalid URL is rejected', () {
    const config = SupabaseConfig(
      url: 'http://project-ref.supabase.co',
      publishableKey: key,
    );
    expect(
      config.validate,
      throwsA(
        isA<SupabaseConfigurationException>().having(
          (error) => error.message,
          'message',
          contains('SUPABASE_URL inválida'),
        ),
      ),
    );
  });

  test('empty and non-client keys are rejected', () {
    expect(
      const SupabaseConfig(url: url, publishableKey: ' ').validate,
      throwsA(isA<SupabaseConfigurationException>()),
    );
    expect(
      const SupabaseConfig(
        url: url,
        publishableKey: 'sb_secret_test_key',
      ).validate,
      throwsA(isA<SupabaseConfigurationException>()),
    );
  });

  test('legacy anon JWT remains accepted but service role does not', () {
    String jwt(String role) {
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({'role': role})))
          .replaceAll('=', '');
      return 'eyJhbGciOiJub25lIn0.$payload.signature';
    }

    expect(
      SupabaseConfig(url: url, publishableKey: jwt('anon')).validate,
      returnsNormally,
    );
    expect(
      SupabaseConfig(url: url, publishableKey: jwt('service_role')).validate,
      throwsA(isA<SupabaseConfigurationException>()),
    );
  });

  test(
    'diagnostics contain only booleans and logs never expose values',
    () async {
      const config = SupabaseConfig(url: url, publishableKey: key);
      expect(config.diagnostics.values, everyElement(isA<bool>()));
      expect(config.diagnostics.toString(), isNot(contains(url)));
      expect(config.diagnostics.toString(), isNot(contains(key)));

      final oldDebugPrint = debugPrint;
      final logs = <String>[];
      debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
      try {
        await initializeSupabase(
          config: config,
          initialize: ({required url, required publishableKey}) async {},
        );
      } finally {
        debugPrint = oldDebugPrint;
      }

      final log = logs.join('\n');
      expect(log, contains('URL presente: SIM'));
      expect(log, contains('prefixo esperado: SIM'));
      expect(log, contains('Supabase inicializado: SIM'));
      expect(log, isNot(contains(url)));
      expect(log, isNot(contains(key)));
    },
  );

  test('initialization failure logs status without the error or key', () async {
    const config = SupabaseConfig(url: url, publishableKey: key);
    final oldDebugPrint = debugPrint;
    final logs = <String>[];
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    try {
      await expectLater(
        initializeSupabase(
          config: config,
          initialize: ({required url, required publishableKey}) async {
            throw StateError(key);
          },
        ),
        throwsA(isA<StateError>()),
      );
    } finally {
      debugPrint = oldDebugPrint;
    }

    final log = logs.join('\n');
    expect(log, contains('Supabase inicializado: NÃO (StateError)'));
    expect(log, isNot(contains(key)));
  });
}
