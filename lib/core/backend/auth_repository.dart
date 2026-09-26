import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'supabase_config.dart';

class AuthRepository {
  AuthRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get changes => _client.auth.onAuthStateChange;

  String get _redirectTo =>
      kIsWeb ? SupabaseConfig.webAuthCallback : 'provasocial://login-callback';

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String displayName,
  }) => _client.auth.signUp(
    email: email.trim(),
    password: password,
    data: {'display_name': displayName.trim()},
    emailRedirectTo: _redirectTo,
  );

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) =>
      _client.auth.signInWithPassword(email: email.trim(), password: password);

  Future<bool> signInWithGoogle() => _client.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: _redirectTo,
    authScreenLaunchMode: kIsWeb
        ? LaunchMode.platformDefault
        : LaunchMode.externalApplication,
  );

  Future<void> sendPasswordReset(String email) =>
      _client.auth.resetPasswordForEmail(email.trim(), redirectTo: _redirectTo);

  Future<void> signOut() => _client.auth.signOut();
}
