import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/backend/supabase_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) usePathUrlStrategy();
  runApp(ProvaSocialApp(initialize: _initializeApp));
}

Future<void> _initializeApp() async {
  final config = SupabaseConfig.current;
  await initializeSupabase(
    config: config,
    initialize: ({required url, required publishableKey}) async {
      await Supabase.initialize(url: url, publishableKey: publishableKey);
    },
  );
}
