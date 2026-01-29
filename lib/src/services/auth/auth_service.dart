import 'dart:async';
import '../api/api_client.dart';
import '../api/token_service.dart';

/// 소셜 로그인 결과
class SocialLoginResult {
  final bool success;
  final bool signupRequired;
  final String? provider;
  final String? providerId;
  final String? providerEmail;

  const SocialLoginResult._({
    required this.success,
    this.signupRequired = false,
    this.provider,
    this.providerId,
    this.providerEmail,
  });

  factory SocialLoginResult.authenticated() =>
      const SocialLoginResult._(success: true);

  factory SocialLoginResult.signupNeeded({
    required String provider,
    String? providerId,
    String? providerEmail,
  }) =>
      SocialLoginResult._(
        success: false,
        signupRequired: true,
        provider: provider,
        providerId: providerId,
        providerEmail: providerEmail,
      );
}

/// 연동된 소셜 계정 정보
class LinkedSocialAccount {
  final String provider;
  final String? providerEmail;
  final String createdAt;

  const LinkedSocialAccount({
    required this.provider,
    this.providerEmail,
    required this.createdAt,
  });

  factory LinkedSocialAccount.fromJson(Map<String, dynamic> json) {
    return LinkedSocialAccount(
      provider: json['provider'] as String,
      providerEmail: json['provider_email'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

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

  /// Google 로그인 (회원가입 필요 여부 확인)
  Future<SocialLoginResult> signInWithGoogle({required String idToken}) async {
    final response = await _api.post('/auth/oauth/google', body: {
      'id_token': idToken,
    }, auth: false);

    return _handleOAuthResponse(response);
  }

  /// Apple 로그인 (회원가입 필요 여부 확인)
  Future<SocialLoginResult> signInWithApple({required String idToken}) async {
    final response = await _api.post('/auth/oauth/apple', body: {
      'id_token': idToken,
    }, auth: false);

    return _handleOAuthResponse(response);
  }

  /// Kakao 로그인 (회원가입 필요 여부 확인)
  Future<SocialLoginResult> signInWithKakao({required String accessToken}) async {
    final response = await _api.post('/auth/oauth/kakao', body: {
      'access_token': accessToken,
    }, auth: false);

    return _handleOAuthResponse(response);
  }

  /// OAuth 응답 처리 공통 로직
  Future<SocialLoginResult> _handleOAuthResponse(dynamic response) async {
    final map = response as Map<String, dynamic>;
    final responseStatus = map['status'] as String?;

    if (responseStatus == 'signup_required') {
      return SocialLoginResult.signupNeeded(
        provider: map['provider'] as String? ?? '',
        providerId: map['provider_id'] as String?,
        providerEmail: map['provider_email'] as String?,
      );
    }

    // 인증 성공 - 토큰 저장
    await _tokenService.saveTokens(
      accessToken: map['access_token'] as String,
      refreshToken: map['refresh_token'] as String,
    );
    return SocialLoginResult.authenticated();
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

  // --- 소셜 계정 연동 관리 ---

  /// 소셜 계정 연동
  Future<void> linkSocialAccount({
    required String provider,
    required String providerId,
    String? providerEmail,
  }) async {
    await _api.post('/users/me/social-accounts', body: {
      'provider': provider,
      'provider_id': providerId,
      if (providerEmail != null) 'provider_email': providerEmail,
    });
  }

  /// 연동된 소셜 계정 목록 조회
  Future<List<LinkedSocialAccount>> getSocialAccounts() async {
    final response = await _api.get('/users/me/social-accounts');
    final list = response as List<dynamic>;
    return list
        .map((e) => LinkedSocialAccount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 소셜 계정 연동 해제
  Future<void> unlinkSocialAccount(String provider) async {
    await _api.delete('/users/me/social-accounts/$provider');
  }
}
