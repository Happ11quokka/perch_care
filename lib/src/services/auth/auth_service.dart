import 'package:perch_care/src/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Wrapper around Supabase auth APIs for dependency injection and testing.
class AuthService {
  AuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// 현재 로그인한 사용자
  User? get currentUser => _client.auth.currentUser;

  /// 로그인 상태 스트림
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// 이메일 회원가입
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? nickname,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: AppConfig.authRedirectUri,
      data: nickname != null ? {'nickname': nickname} : null,
    );

    // 프로필 닉네임 업데이트 (트리거가 자동 생성하므로 업데이트만)
    if (response.user != null && nickname != null) {
      await _client.from('profiles').update({
        'nickname': nickname,
      }).eq('id', response.user!.id);
    }

    return response;
  }

  /// 이메일 로그인
  Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Google 로그인
  Future<void> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: AppConfig.authRedirectUri,
    );
  }

  /// Apple 로그인
  Future<void> signInWithApple() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: AppConfig.authRedirectUri,
    );
  }

  /// Kakao 로그인
  Future<void> signInWithKakao() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.kakao,
      redirectTo: AppConfig.authRedirectUri,
    );
  }

  /// 로그아웃
  Future<void> signOut() {
    return _client.auth.signOut();
  }

  /// 비밀번호 재설정 이메일 전송
  Future<void> resetPassword(String email) {
    return _client.auth.resetPasswordForEmail(
      email,
      redirectTo: AppConfig.authRedirectUri,
    );
  }

  /// 프로필 조회
  Future<Map<String, dynamic>?> getProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final response = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    return response;
  }

  /// 프로필 업데이트
  Future<void> updateProfile({
    String? nickname,
    String? avatarUrl,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('User not logged in');

    final updates = <String, dynamic>{};
    if (nickname != null) updates['nickname'] = nickname;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    if (updates.isNotEmpty) {
      await _client.from('profiles').update(updates).eq('id', user.id);
    }
  }
}
