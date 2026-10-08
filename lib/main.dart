import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/import/pdf_text_extractor.dart';
import 'core/backend/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? startupError;
  try {
    await _initializeApp();
  } catch (error) {
    startupError = error;
    debugPrint('[STARTUP] Inicialização falhou (${error.runtimeType}).');
  }

  runApp(
    ProvaSocialApp(
      initialize: startupError == null
          ? _alreadyInitialized
          : () => Future<void>.error(startupError!),
    ),
  );
}

Future<void> _initializeApp() async {
  final config = SupabaseConfig.current;
  await initializeSupabase(
    config: config,
    beforeSupabaseInitialize: () async {
      debugPrint('[STARTUP] Inicializando pdfrx.');
      await PdfTextExtractor.initialize();
    },
    initialize: ({required url, required publishableKey}) async {
      await Supabase.initialize(url: url, publishableKey: publishableKey);
    },
  );
}

Future<void> _alreadyInitialized() async {}
