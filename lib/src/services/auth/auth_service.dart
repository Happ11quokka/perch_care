import 'package:perch_care/src/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Wrapper around Supabase auth APIs for dependency injection and testing.
class AuthService {
  AuthService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) =>
      _client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: AppConfig.authRedirectUri,
      );

  Future<void> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: AppConfig.authRedirectUri,
    );
  }

  Future<void> signInWithApple() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: AppConfig.authRedirectUri,
    );
  }

  Future<void> signOut() {
    return _client.auth.signOut();
  }
}
