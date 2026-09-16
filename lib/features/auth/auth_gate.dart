import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../home/home_page.dart';
import 'auth_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = snapshot.data?.session ??
              Supabase.instance.client.auth.currentSession;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: session == null
                ? const AuthPage(key: ValueKey('auth'))
                : const HomePage(key: ValueKey('home')),
          );
        },
      );
}
