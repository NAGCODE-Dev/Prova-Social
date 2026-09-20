import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_page.dart';
import '../onboarding/onboarding_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? completed;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => completed = preferences.getBool('onboarding_complete') ?? false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (completed == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return completed! ? const HomePage() : const OnboardingPage();
  }
}
