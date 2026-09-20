import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/backend/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProvaSocialApp(initialize: _initializeApp));
}

Future<void> _initializeApp() async {
  await pdfrxFlutterInitialize();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.publishableKey,
  );
}
