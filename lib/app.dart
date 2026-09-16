import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/update/update_gate.dart';
import 'features/auth/auth_gate.dart';

class ProvaSocialApp extends StatelessWidget {
  const ProvaSocialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prova Social',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const UpdateGate(child: AuthGate()),
    );
  }
}
