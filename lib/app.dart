import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/update/update_gate.dart';
import 'core/startup/startup_gate.dart';
import 'features/auth/auth_gate.dart';

class ProvaSocialApp extends StatelessWidget {
  const ProvaSocialApp({required this.initialize, super.key});

  final Future<void> Function() initialize;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prova Social',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: StartupGate(
        initialize: initialize,
        child: const UpdateGate(child: AuthGate()),
      ),
    );
  }
}
