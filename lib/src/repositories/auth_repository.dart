import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../services/auth/auth_service.dart';
import '../services/api/token_service.dart';

/// 로그인 결과 — 이메일/소셜 공통. hasPets를 결과에 실어 라우팅 재조회를 없앤다.
sealed class LoginOutcome {}

/// 인증 성공. [hasPets]는 tri-state(true/false/null)를 그대로 보존한다.
///
/// - true  : 확실히 펫이 있음
/// - false : 확실히 펫이 없음
/// - null  : 확인 실패 — 호출자는 안전한 기본 분기로 가야 한다
class LoginAuthenticated extends LoginOutcome {
  LoginAuthenticated(this.hasPets);
  final bool? hasPets;
}

/// 소셜 로그인 시 서버가 회원가입이 필요하다고 응답한 경우.
class LoginSignupRequired extends LoginOutcome {
  LoginSignupRequired({required this.provider, this.providerId, this.providerEmail});
  final String provider;
  final String? providerId;
  final String? providerEmail;
}

/// 인증 도메인 Repository — ViewModel이 의존하는 단일 데이터 접근 지점.
///
/// ViewModel은 이 인터페이스만 바라보고 `AuthService` / `TokenService` 구현을
/// 직접 알지 못한다. 테스트에서는 Mock Repository를 주입하여 ViewModel만
/// 단위 테스트할 수 있다.
abstract class AuthRepository {
  bool get isLoggedIn;

  Future<LoginOutcome> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? nickname,
    bool marketingAgreed = false,
  });

  /// signup 화면 '나중에/확인' — 이미 저장된 토큰을 버린다.
  Future<void> discardSession();

  /// Task 2에서 credential 획득 계층(GoogleCredential)이 추가되면 시그니처를
  /// credential 객체로 승격한다. Task 1은 AuthService와 1:1 idToken 시그니처.
  Future<LoginOutcome> signInWithGoogle({required String idToken});

  Future<LoginOutcome> signInWithApple({
    required String idToken,
    String? userIdentifier,
    String? fullName,
    String? email,
  });

  /// Google SDK로 idToken을 직접 획득한 뒤 [signInWithGoogle]에 위임한다.
  /// 사용자가 로그인을 취소하면 예외 대신 `null`을 반환한다.
  Future<LoginOutcome?> loginWithGoogle();

  /// Apple SDK로 credential을 직접 획득한 뒤 [signInWithApple]에 위임한다.
  /// 사용자가 로그인을 취소하면 예외 대신 `null`을 반환한다.
  Future<LoginOutcome?> loginWithApple();

  Future<void> signOut();

  Future<void> deleteAccount();

  Future<void> resetPassword(String email);

  Future<void> resetPasswordByPhone(String phone);

  Future<void> verifyResetCode(
    String identifier,
    String code, {
    String method = 'email',
  });

  Future<void> updatePassword({
    required String identifier,
    required String code,
    required String newPassword,
    String method = 'email',
  });

  Future<Map<String, dynamic>?> getProfile();

  Future<void> updateProfile({String? nickname, String? avatarUrl});

  /// 펫 보유 여부 확인 (첫 로그인 판별용). tri-state(true/false/null)를 그대로 전달한다.
  Future<bool?> hasPets();

  Future<void> linkSocialAccount({
    required String provider,
    String? idToken,
    String? accessToken,
    String? providerId,
    String? providerEmail,
  });

  Future<List<LinkedSocialAccount>> getSocialAccounts();

  Future<void> unlinkSocialAccount(String provider);
}

/// 기본 구현 — 기존 `AuthService` + `TokenService`를 래핑한다.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({AuthService? service, TokenService? tokenService})
      : _service = service ?? AuthService.instance,
        _tokenService = tokenService ?? TokenService.instance;

  final AuthService _service;
  final TokenService _tokenService;

  @override
  bool get isLoggedIn => _service.isLoggedIn;

  @override
  Future<LoginOutcome> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _service.signInWithEmailPassword(email: email, password: password);
    final hasPets = await _service.hasPets();
    return LoginAuthenticated(hasPets);
  }

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? nickname,
    bool marketingAgreed = false,
  }) {
    return _service.signUpWithEmail(
      email: email,
      password: password,
      nickname: nickname,
      marketingAgreed: marketingAgreed,
    );
  }

  @override
  Future<void> discardSession() => _tokenService.clearTokens();

  @override
  Future<LoginOutcome> signInWithGoogle({required String idToken}) async {
    final result = await _service.signInWithGoogle(idToken: idToken);
    return _mapSocialResult(result);
  }

  @override
  Future<LoginOutcome> signInWithApple({
    required String idToken,
    String? userIdentifier,
    String? fullName,
    String? email,
  }) async {
    final result = await _service.signInWithApple(
      idToken: idToken,
      userIdentifier: userIdentifier,
      fullName: fullName,
      email: email,
    );
    return _mapSocialResult(result);
  }

  @override
  Future<LoginOutcome?> loginWithGoogle() async {
    final GoogleSignInAccount account;
    try {
      final signIn = GoogleSignIn.instance;
      account = await signIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) throw Exception('idToken is null');
    return signInWithGoogle(idToken: idToken);
  }

  @override
  Future<LoginOutcome?> loginWithApple() async {
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
    final idToken = credential.identityToken;
    if (idToken == null) throw Exception('identityToken is null');

    // fullName 조합 (Apple은 최초 로그인 시에만 이름 제공)
    String? fullName;
    if (credential.givenName != null || credential.familyName != null) {
      fullName = '${credential.givenName ?? ''} ${credential.familyName ?? ''}'
          .trim();
      if (fullName.isEmpty) fullName = null;
    }

    return signInWithApple(
      idToken: idToken,
      userIdentifier: credential.userIdentifier,
      fullName: fullName,
      email: credential.email,
    );
  }

  Future<LoginOutcome> _mapSocialResult(SocialLoginResult result) async {
    if (result.signupRequired) {
      return LoginSignupRequired(
        provider: result.provider!,
        providerId: result.providerId,
        providerEmail: result.providerEmail,
      );
    }
    // result.hasPets는 서버가 has_pets를 생략하면 false로 디폴트되어 tri-state를
    // 잃는다. service.hasPets()를 다시 거쳐 tri-state(null 시 GET /pets/ 폴백)를
    // 보존한다 — signInWithEmail과 동일한 경로.
    return LoginAuthenticated(await _service.hasPets());
  }

  @override
  Future<void> signOut() => _service.signOut();

  @override
  Future<void> deleteAccount() => _service.deleteAccount();

  @override
  Future<void> resetPassword(String email) => _service.resetPassword(email);

  @override
  Future<void> resetPasswordByPhone(String phone) =>
      _service.resetPasswordByPhone(phone);

  @override
  Future<void> verifyResetCode(
    String identifier,
    String code, {
    String method = 'email',
  }) {
    return _service.verifyResetCode(identifier, code, method: method);
  }

  @override
  Future<void> updatePassword({
    required String identifier,
    required String code,
    required String newPassword,
    String method = 'email',
  }) {
    return _service.updatePassword(
      identifier: identifier,
      code: code,
      newPassword: newPassword,
      method: method,
    );
  }

  @override
  Future<Map<String, dynamic>?> getProfile() => _service.getProfile();

  @override
  Future<void> updateProfile({String? nickname, String? avatarUrl}) {
    return _service.updateProfile(nickname: nickname, avatarUrl: avatarUrl);
  }

  @override
  Future<bool?> hasPets() => _service.hasPets();

  @override
  Future<void> linkSocialAccount({
    required String provider,
    String? idToken,
    String? accessToken,
    String? providerId,
    String? providerEmail,
  }) {
    return _service.linkSocialAccount(
      provider: provider,
      idToken: idToken,
      accessToken: accessToken,
      providerId: providerId,
      providerEmail: providerEmail,
    );
  }

  @override
  Future<List<LinkedSocialAccount>> getSocialAccounts() =>
      _service.getSocialAccounts();

  @override
  Future<void> unlinkSocialAccount(String provider) =>
      _service.unlinkSocialAccount(provider);
}
