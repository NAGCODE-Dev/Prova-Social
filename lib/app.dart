import 'package:flutter/material.dart';

import 'core/navigation/share_link_service.dart';
import 'core/theme/app_theme.dart';
import 'core/update/update_gate.dart';
import 'core/startup/startup_gate.dart';
import 'core/widgets/emerald_backdrop.dart';
import 'features/auth/auth_gate.dart';
import 'features/share/share_link_page.dart';

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
      themeMode: ThemeMode.dark,
      builder: (context, child) =>
          EmeraldBackdrop(child: child ?? const SizedBox.shrink()),
      onGenerateInitialRoutes: (initialRoute) => [
        MaterialPageRoute<void>(
          settings: RouteSettings(name: initialRoute),
          builder: (_) => StartupGate(
            initialize: initialize,
            child: UpdateGate(child: _initialPage(initialRoute)),
          ),
        ),
      ],
      onGenerateRoute: (settings) {
        final destination = ShareLinkService.parse(settings.name);
        if (destination == null) return null;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => ShareLinkPage(destination: destination),
        );
      },
    );
  }

  Widget _initialPage(String route) {
    final destination = ShareLinkService.parse(route);
    return destination == null
        ? const AuthGate()
        : ShareLinkPage(destination: destination);
  }
}
