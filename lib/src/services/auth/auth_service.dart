import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../api/api_client.dart';
import '../api/token_service.dart';
import '../pet/pet_local_cache_service.dart';
import '../pet/pet_service.dart';
import '../premium/premium_service.dart';
import '../weight/weight_service.dart';
import '../storage/health_check_storage_service.dart';
import '../storage/chat_storage_service.dart';
import '../coach_mark/coach_mark_service.dart';
import '../analytics/analytics_service.dart';
import '../iap/iap_service.dart';
import '../push/push_notification_service.dart';
import '../storage/local_image_storage_service.dart';

/// 소셜 로그인 결과
class SocialLoginResult {
  final bool success;
  final bool signupRequired;
  final String? provider;
  final String? providerId;
  final String? providerEmail;
  /// 서버가 알려준 펫 보유 여부. 인증 성공 시에만 의미 있음.
  final bool hasPets;

  const SocialLoginResult._({
    required this.success,
    this.signupRequired = false,
    this.provider,
    this.providerId,
    this.providerEmail,
    this.hasPets = false,
  });

  factory SocialLoginResult.authenticated({bool hasPets = false}) =>
      SocialLoginResult._(success: true, hasPets: hasPets);

  factory SocialLoginResult.signupNeeded({
    required String provider,
    String? providerId,
    String? providerEmail,
  }) => SocialLoginResult._(
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
  AuthService._();
  static final AuthService instance = AuthService._();

  final _api = ApiClient.instance;
  final _tokenService = TokenService.instance;
  final _petCache = PetLocalCacheService.instance;

  /// 가장 최근 인증 응답에서 서버가 알려준 펫 보유 여부.
  /// 신규 가입은 false, 기존 계정 로그인은 서버 DB 기준.
  /// null = 응답에 필드가 없거나 아직 로그인 전.
  bool? _lastHasPets;
  bool? get lastHasPets => _lastHasPets;

  /// 현재 로그인 여부
  bool get isLoggedIn => _tokenService.isLoggedIn;

  /// 현재 사용자 ID
  String? get currentUserId => _tokenService.userId;

  /// 이메일 회원가입
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? nickname,
    bool marketingAgreed = false,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
      if (nickname != null) 'nickname': nickname,
      'marketing_agreed': marketingAgreed,
    };

    final response = await _api.post('/auth/signup', body: body, auth: false);
    await _tokenService.saveTokens(
      accessToken: response['access_token'],
      refreshToken: response['refresh_token'],
    );
    _lastHasPets = response['has_pets'] as bool? ?? false;
    await _initializeAuthenticatedServices();
    AnalyticsService.instance.logSignUp('email');
  }

  /// 이메일 로그인
  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final response = await _api.post(
      '/auth/login',
      body: {'email': email, 'password': password},
      auth: false,
    );

    await _tokenService.saveTokens(
      accessToken: response['access_token'],
      refreshToken: response['refresh_token'],
    );
    _lastHasPets = response['has_pets'] as bool?;
    await _initializeAuthenticatedServices();
    AnalyticsService.instance.logLogin('email');
  }

  /// Google 로그인 (회원가입 필요 여부 확인)
  Future<SocialLoginResult> signInWithGoogle({required String idToken}) async {
    final response = await _api.post(
      '/auth/oauth/google',
      body: {'id_token': idToken},
      auth: false,
    );

    final result = await _handleOAuthResponse(response);
    if (result.success) AnalyticsService.instance.logLogin('google');
    return result;
  }

  /// Apple 로그인 (회원가입 필요 여부 확인)
  Future<SocialLoginResult> signInWithApple({
    required String idToken,
    String? userIdentifier,
    String? fullName,
    String? email,
  }) async {
    final response = await _api.post(
      '/auth/oauth/apple',
      body: {
        'id_token': idToken,
        if (userIdentifier != null) 'user_identifier': userIdentifier,
        if (fullName != null) 'full_name': fullName,
        if (email != null) 'email': email,
      },
      auth: false,
    );

    final result = await _handleOAuthResponse(response);
    if (result.success) AnalyticsService.instance.logLogin('apple');
    return result;
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
    final hasPets = map['has_pets'] as bool? ?? false;
    _lastHasPets = map['has_pets'] as bool?;
    await _initializeAuthenticatedServices();
    return SocialLoginResult.authenticated(hasPets: hasPets);
  }

  Future<void> _initializeAuthenticatedServices() async {
    unawaited(PushNotificationService.instance.initialize());
    await IapService.instance.initialize();
  }

  /// 로그아웃
  Future<void> signOut() async {
    // FCM 디바이스 토큰 삭제 (서버에서 푸시 대상 제거)
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await _api.delete('/users/me/device-token', body: {'token': fcmToken});
      }
    } catch (_) {
      // 토큰 삭제 실패해도 로그아웃은 진행
    }
    // 인메모리 캐시 무효화
    PetService.instance.invalidateCache();
    PremiumService.instance.invalidateCache();
    WeightService.instance.clearAllRecords();

    // 로컬 스토리지 정리
    await _petCache.clearAll();
    await LocalImageStorageService.instance.clearAll();
    await HealthCheckStorageService.instance.clearAll();
    await ChatStorageService.instance.clearAllMessages();
    await CoachMarkService.instance.clearAll();
    await PushNotificationService.instance.dispose();
    IapService.instance.dispose();
    await _tokenService.clearTokens();
    _lastHasPets = null;
  }

  /// 비밀번호 재설정 코드 전송 (이메일)
  Future<void> resetPassword(String email) async {
    await _api.post(
      '/auth/reset-password',
      body: {'email': email},
      auth: false,
    );
  }

  /// 비밀번호 재설정 코드 전송 (휴대폰)
  Future<void> resetPasswordByPhone(String phone) async {
    await _api.post(
      '/auth/reset-password',
      body: {'phone': phone},
      auth: false,
    );
  }

  /// 비밀번호 재설정 코드 검증
  Future<void> verifyResetCode(
    String identifier,
    String code, {
    String method = 'email',
  }) async {
    final body = <String, dynamic>{'code': code};
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
    final body = <String, dynamic>{'code': code, 'new_password': newPassword};
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
  Future<void> updateProfile({String? nickname, String? avatarUrl}) async {
    final updates = <String, dynamic>{};
    if (nickname != null) updates['nickname'] = nickname;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    if (updates.isNotEmpty) {
      await _api.put('/users/me/profile', body: updates);
    }
  }

  /// 펫 보유 여부 확인 (첫 로그인 판별용).
  ///
  /// 반환값 의미:
  /// - true  : 확실히 펫이 있음
  /// - false : 확실히 펫이 없음 (서버에서 빈 리스트 / has_pets=false 명시)
  /// - null  : 확인 실패 (네트워크/타임아웃/서버 에러 등) — 호출자는 안전한 기본 분기로 가야 함
  ///
  /// 라우팅에서 false와 null을 같이 처리하면 기존 사용자가 잘못 onboarding으로 빠진다.
  Future<bool?> hasPets() async {
    // 직전 인증 응답에 서버가 has_pets를 실어줬다면 그 값을 신뢰 (네트워크 1회 절약 + race 방지)
    final cached = _lastHasPets;
    if (cached != null) return cached;
    try {
      final response = await _api.get('/pets/');
      if (response is! List) return null;
      return response.isNotEmpty;
    } catch (_) {
      return null;
    }
  }

  // --- 소셜 계정 연동 관리 ---

  /// 회원 탈퇴
  Future<void> deleteAccount() async {
    AnalyticsService.instance.logAccountDeleted();
    await _api.delete('/users/me');

    // 인메모리 캐시 무효화
    PetService.instance.invalidateCache();
    PremiumService.instance.invalidateCache();
    WeightService.instance.clearAllRecords();

    // 로컬 스토리지 정리
    await _petCache.clearAll();
    await LocalImageStorageService.instance.clearAll();
    await HealthCheckStorageService.instance.clearAll();
    await ChatStorageService.instance.clearAllMessages();
    await CoachMarkService.instance.clearAll();
    await _tokenService.clearTokens();
  }

  /// 소셜 계정 연동
  Future<void> linkSocialAccount({
    required String provider,
    String? idToken,
    String? accessToken,
    String? providerId,
    String? providerEmail,
  }) async {
    await _api.post(
      '/users/me/social-accounts',
      body: {
        'provider': provider,
        if (idToken != null) 'id_token': idToken,
        if (accessToken != null) 'access_token': accessToken,
        if (providerId != null) 'provider_id': providerId,
        if (providerEmail != null) 'provider_email': providerEmail,
      },
    );
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
