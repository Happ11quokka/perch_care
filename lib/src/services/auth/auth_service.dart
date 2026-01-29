import 'dart:async';
import '../api/api_client.dart';
import '../api/token_service.dart';

/// FastAPI 기반 인증 서비스
class AuthService {
  AuthService();

  final _api = ApiClient.instance;
  final _tokenService = TokenService.instance;

  /// 현재 로그인 여부
  bool get isLoggedIn => _tokenService.isLoggedIn;

  /// 현재 사용자 ID
  String? get currentUserId => _tokenService.userId;

  /// 이메일 회원가입
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? nickname,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
      if (nickname != null) 'nickname': nickname,
    };

    final response = await _api.post('/auth/signup', body: body, auth: false);
    await _tokenService.saveTokens(
      accessToken: response['access_token'],
      refreshToken: response['refresh_token'],
    );
  }

  /// 이메일 로그인
  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final response = await _api.post('/auth/login', body: {
      'email': email,
      'password': password,
    }, auth: false);

    await _tokenService.saveTokens(
      accessToken: response['access_token'],
      refreshToken: response['refresh_token'],
    );
  }

  /// Google 로그인
  Future<void> signInWithGoogle({required String idToken}) async {
    final response = await _api.post('/auth/oauth/google', body: {
      'id_token': idToken,
    }, auth: false);

    await _tokenService.saveTokens(
      accessToken: response['access_token'],
      refreshToken: response['refresh_token'],
    );
  }

  /// Apple 로그인
  Future<void> signInWithApple({required String idToken}) async {
    final response = await _api.post('/auth/oauth/apple', body: {
      'id_token': idToken,
    }, auth: false);

    await _tokenService.saveTokens(
      accessToken: response['access_token'],
      refreshToken: response['refresh_token'],
    );
  }

  /// Kakao 로그인
  Future<void> signInWithKakao({required String accessToken}) async {
    final response = await _api.post('/auth/oauth/kakao', body: {
      'access_token': accessToken,
    }, auth: false);

    await _tokenService.saveTokens(
      accessToken: response['access_token'],
      refreshToken: response['refresh_token'],
    );
  }

  /// 로그아웃
  Future<void> signOut() async {
    await _tokenService.clearTokens();
  }

  /// 비밀번호 재설정 코드 전송 (이메일)
  Future<void> resetPassword(String email) async {
    await _api.post('/auth/reset-password', body: {'email': email}, auth: false);
  }

  /// 비밀번호 재설정 코드 전송 (휴대폰)
  Future<void> resetPasswordByPhone(String phone) async {
    await _api.post('/auth/reset-password', body: {'phone': phone}, auth: false);
  }

  /// 비밀번호 재설정 코드 검증
  Future<void> verifyResetCode(String identifier, String code, {String method = 'email'}) async {
    final body = <String, dynamic>{
      'code': code,
    };
    if (method == 'phone') {
      body['phone'] = identifier;
    } else {
      body['email'] = identifier;
    }
    await _api.post('/auth/verify-reset-code', body: body, auth: false);
  }

  /// 새 비밀번호 설정
  Future<void> updatePassword({
    required String identifier,
    required String code,
    required String newPassword,
    String method = 'email',
  }) async {
    final body = <String, dynamic>{
      'code': code,
      'new_password': newPassword,
    };
    if (method == 'phone') {
      body['phone'] = identifier;
    } else {
      body['email'] = identifier;
    }
    await _api.post('/auth/update-password', body: body, auth: false);
  }

  /// 프로필 조회
  Future<Map<String, dynamic>?> getProfile() async {
    if (!isLoggedIn) return null;
    final response = await _api.get('/users/me/profile');
    return response as Map<String, dynamic>;
  }

  /// 프로필 업데이트
  Future<void> updateProfile({
    String? nickname,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (nickname != null) updates['nickname'] = nickname;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    if (updates.isNotEmpty) {
      await _api.put('/users/me/profile', body: updates);
    }
  }
}
