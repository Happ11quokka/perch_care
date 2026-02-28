# 플랫폼 인증 종합 레퍼런스

> **목적:** perch_care 앱의 Google, Apple, Kakao OAuth 인증 및 플랫폼별 설정을 종합 정리한 레퍼런스 문서

---

## 1. 개요

### 지원 플랫폼

| 플랫폼 | 상태 | 비고 |
|--------|------|------|
| iOS | 완전 지원 | Google, Apple, Kakao 모두 지원 |
| Android | 완전 지원 | Google, Apple(제한적), Kakao 모두 지원 |
| macOS | 부분 지원 | Deep link만 설정, Firebase 미설정 |
| Web | 미지원 | Firebase options 미설정 |

### 인증 제공자 비교

| 제공자 | 토큰 타입 | 클라이언트 검증 | 백엔드 검증 방식 |
|--------|-----------|----------------|-----------------|
| Google | `id_token` (JWT) | 가능 | JWT 서명 검증 |
| Apple | `id_token` (JWT) | 가능 | JWT 서명 검증 |
| Kakao | `access_token` (Opaque) | 불가 | Kakao API 호출로 검증 |
| Email | - | - | 자체 검증 |

### 인증 아키텍처 흐름

```
[사용자] → [Flutter 앱 (SDK 호출)] → [OAuth 제공자 (Google/Apple/Kakao)]
                                              ↓
                                       토큰 반환 (id_token 또는 access_token)
                                              ↓
[Flutter 앱] → POST /auth/oauth/{provider} → [FastAPI 백엔드]
                                              ↓
                                       백엔드에서 토큰 검증
                                              ↓
                                       JWT access_token + refresh_token 발급
                                              ↓
[Flutter 앱] ← 응답 ← [FastAPI 백엔드]
       ↓
flutter_secure_storage에 토큰 저장
```

---

## 2. Google OAuth

### 설정값

| 항목 | 값 |
|------|---|
| Client ID (iOS) | `351000470573-9cu20o306ho5jepgee2b474jnd0ah08b.apps.googleusercontent.com` |
| Server Client ID | `351000470573-ivirja6bvfpqk0rsg1shd048erdk1tv4.apps.googleusercontent.com` |
| SDK | `google_sign_in: ^7.2.0` |
| 백엔드 엔드포인트 | `POST /auth/oauth/google` |

### iOS 설정 (`ios/Runner/Info.plist`)

```xml
<dict>
    <key>CFBundleURLSchemes</key>
    <array>
        <string>com.googleusercontent.apps.351000470573-9cu20o306ho5jepgee2b474jnd0ah08b</string>
    </array>
</dict>
```

- Google Cloud Console에서 OAuth 동의 화면 및 클라이언트 설정 필요
- iOS 번들 ID: `com.perch.perchCare`

### Android 설정

- 별도 매니페스트 설정 불필요 (Google SDK가 자동 처리)
- 패키지명: `com.perch.perch_care`
- `android/app/google-services.json`에 Firebase 설정 포함

### SDK 초기화 (`lib/src/screens/splash/splash_screen.dart`)

```dart
Future<void> _initGoogleSignIn() async {
  try {
    await GoogleSignIn.instance.initialize(
      clientId: '351000470573-9cu20o306ho5jepgee2b474jnd0ah08b.apps.googleusercontent.com',
      serverClientId: '351000470573-ivirja6bvfpqk0rsg1shd048erdk1tv4.apps.googleusercontent.com',
    );
  } catch (e) {
    debugPrint('[Splash] GoogleSignIn init error: $e');
  }
}
```

- Splash 화면에서 병렬 초기화 (`Future.wait`)
- 초기화 실패해도 앱 기동 차단하지 않음

### 인증 플로우 (`lib/src/screens/login/login_screen.dart`)

```dart
// 1. Google SDK로 인증 요청
final signIn = GoogleSignIn.instance;
final account = await signIn.authenticate();

// 2. id_token 추출
final idToken = account.authentication.idToken;

// 3. 백엔드로 전송
final result = await _authService.signInWithGoogle(idToken: idToken);

// 4. 결과 처리
_handleSocialLoginResult(result);
```

### Google Cloud Console 설정 체크리스트

- [ ] OAuth 동의 화면 구성
- [ ] iOS 클라이언트 ID 생성 (번들 ID: `com.perch.perchCare`)
- [ ] Android 클라이언트 ID 생성 (패키지명: `com.perch.perch_care`, SHA-1 등록)
- [ ] Web 클라이언트 ID 생성 (Server Client ID로 사용)

---

## 3. Apple Sign In

### 설정값

| 항목 | 값 |
|------|---|
| SDK | `sign_in_with_apple: ^7.0.1` |
| 백엔드 엔드포인트 | `POST /auth/oauth/apple` |
| 필요 스코프 | `email`, `fullName` |

### iOS 설정

- Xcode에서 "Sign in with Apple" capability 활성화 필수
- 별도 URL Scheme 불필요 (iOS 시스템이 자동 처리)
- Apple Developer 계정에서 App ID에 Sign in with Apple 서비스 활성화

### macOS 설정 (`macos/Runner/Info.plist`)

```xml
<dict>
    <key>CFBundleURLName</key>
    <string>perchcare</string>
    <key>CFBundleURLSchemes</key>
    <array>
        <string>perchcare</string>
    </array>
</dict>
```

### 인증 플로우 (`lib/src/screens/login/login_screen.dart`)

```dart
// 1. Apple ID 자격 증명 요청
final credential = await SignInWithApple.getAppleIDCredential(
  scopes: [
    AppleIDAuthorizationScopes.email,
    AppleIDAuthorizationScopes.fullName,
  ],
);

// 2. JWT identity token 추출
final idToken = credential.identityToken;

// 3. 사용자 정보 추출
final userIdentifier = credential.userIdentifier;
final fullName = '${credential.givenName ?? ''} ${credential.familyName ?? ''}'.trim();
final email = credential.email;

// 4. 백엔드로 전송
final result = await _authService.signInWithApple(
  idToken: idToken,
  userIdentifier: userIdentifier,
  fullName: fullName,
  email: email,
);
```

### 주의사항

| 항목 | 설명 |
|------|------|
| 이름/이메일 제공 | **최초 로그인 시에만** Apple이 이름과 이메일을 제공. 이후 로그인에서는 `null` |
| 사용자 식별 | `userIdentifier`는 매번 동일하게 제공됨. 이것으로 사용자 매칭 |
| Android 지원 | 네이티브 Apple Sign In 불가. 웹 기반 인증 필요 시 별도 구현 |
| 테스트 | 시뮬레이터에서 테스트 가능하나 실제 Apple ID 필요 |

### Apple Developer 설정 체크리스트

- [ ] App ID에 "Sign in with Apple" 서비스 활성화
- [ ] Provisioning Profile 재생성
- [ ] Xcode에서 Signing & Capabilities → "+ Capability" → "Sign in with Apple" 추가
- [ ] (선택) 웹/Android 지원 시 Services ID 생성

---

## 4. Kakao OAuth

### 설정값

| 항목 | 값 |
|------|---|
| Native App Key | `23f9d1f1b79cea8566c54a44ba33b463` |
| URL Scheme | `kakao23f9d1f1b79cea8566c54a44ba33b463` |
| 백엔드 엔드포인트 | `POST /auth/oauth/kakao` |
| 백엔드 검증 API | `https://kapi.kakao.com/v2/user/me` |

### iOS 설정 (`ios/Runner/Info.plist`)

```xml
<!-- URL Scheme -->
<dict>
    <key>CFBundleURLSchemes</key>
    <array>
        <string>kakao23f9d1f1b79cea8566c54a44ba33b463</string>
    </array>
</dict>

<!-- Query Schemes (카카오 앱 연동) -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>kakaokompassauth</string>
    <string>kakaolink</string>
    <string>kakaoplus</string>
</array>
```

### Android 설정 (`android/app/src/main/AndroidManifest.xml`)

```xml
<activity
    android:name="com.kakao.sdk.flutter.AuthCodeHandlerActivity"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="kakao23f9d1f1b79cea8566c54a44ba33b463"
              android:host="oauth" />
    </intent-filter>
</activity>
```

### 인증 플로우

```dart
// 1. Kakao SDK로 인증 → accessToken 획득
// (네이티브 Kakao SDK가 처리)

// 2. accessToken을 백엔드로 전송
final result = await _authService.signInWithKakao(accessToken: accessToken);
```

### 백엔드 검증 방식 (Google/Apple과의 핵심 차이)

```
[Flutter 앱] → POST /auth/oauth/kakao { access_token } → [FastAPI 백엔드]
                                                                ↓
                                               GET https://kapi.kakao.com/v2/user/me
                                               Authorization: Bearer {access_token}
                                                                ↓
                                               Kakao API가 user_id, email 반환
                                                                ↓
                                               provider_id = Kakao user_id (숫자)
                                                                ↓
                                               JWT 발급 후 앱에 반환
```

- Google/Apple은 **JWT id_token**을 클라이언트에서 받아 백엔드에서 서명 검증
- Kakao는 **opaque access_token**을 받아 백엔드에서 Kakao API를 직접 호출하여 검증
- `provider_id`는 반드시 **Kakao user ID (숫자)**여야 함. access_token 자체를 저장하면 안 됨

### Kakao Developers 설정 체크리스트

- [ ] Kakao Developers 앱 생성
- [ ] 네이티브 앱 키 발급
- [ ] 플랫폼 등록 (iOS: 번들 ID, Android: 패키지명 + 키 해시)
- [ ] 카카오 로그인 활성화
- [ ] 동의 항목 설정 (이메일, 프로필)

### 참고 문서

- 카카오 로그인 수정 이력: `docs/development-logs/2026-01-31-kakao-login-fix.md`

---

## 5. 토큰 관리

### 저장소

| 항목 | 값 |
|------|---|
| 구현 파일 | `lib/src/services/api/token_service.dart` |
| 저장 방식 | `flutter_secure_storage: ^10.0.0` |
| iOS 저장소 | Keychain (`KeychainAccessibility.first_unlock_this_device`) |
| Android 저장소 | Encrypted SharedPreferences |
| 저장 키 | `access_token`, `refresh_token` |

### 토큰 구조

- JWT (JSON Web Token) 형식
- `sub` 클레임에 사용자 ID 포함
- 클라이언트에서 base64 디코딩으로 payload 추출 (서명 검증은 백엔드에서 수행)

### 핵심 API

```dart
// 토큰 저장
Future<void> saveTokens({
  required String accessToken,
  required String refreshToken,
})

// 사용자 ID 추출 (JWT sub 클레임)
String? get userId

// 로그인 상태 확인
bool get isLoggedIn => _initialized && _accessToken != null

// 토큰 삭제 (로그아웃)
Future<void> clearTokens()
```

### 자동 토큰 갱신 (`lib/src/services/api/api_client.dart`)

```
[API 요청] → 401 Unauthorized 응답
       ↓
POST /auth/refresh { refresh_token }
       ↓
새 access_token + refresh_token 저장
       ↓
원래 요청 재시도
```

- **Completer 패턴**으로 동시 갱신 요청 방지
- 갱신 타임아웃: 5초
- 일반 요청 타임아웃: 10초 / 파일 업로드: 30초

### 인증 헤더

```dart
Map<String, String> get _authHeaders => {
  'Content-Type': 'application/json',
  'Authorization': 'Bearer $accessToken',
};
```

---

## 6. Deep Link 설정

### URL 스킴

| 항목 | 값 |
|------|---|
| 스킴 | `perchcare` |
| Auth Callback | `perchcare://auth-callback` |
| 설정 위치 | `lib/src/config/app_config.dart` |

### iOS (`ios/Runner/Info.plist`)

```xml
<dict>
    <key>CFBundleURLName</key>
    <string>perchcare</string>
    <key>CFBundleURLSchemes</key>
    <array>
        <string>perchcare</string>
    </array>
</dict>
```

### Android (`android/app/src/main/AndroidManifest.xml`)

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="perchcare"
        android:host="auth-callback" />
</intent-filter>
```

### macOS (`macos/Runner/Info.plist`)

```xml
<dict>
    <key>CFBundleURLSchemes</key>
    <array>
        <string>perchcare</string>
    </array>
</dict>
```

### 현재 사용 현황

- OAuth 인증은 네이티브 SDK 콜백으로 처리하므로 deep link를 직접 사용하지 않음
- 향후 웹 기반 OAuth나 deferred deep linking 확장 시 활용 가능

---

## 7. Firebase 설정

> Firebase는 인증에 사용하지 않음. FCM 푸시 알림과 Analytics 전용.

### 프로젝트 정보

| 항목 | 값 |
|------|---|
| Project ID | `perch-care` |
| Project Number | `854417470022` |
| Storage Bucket | `perch-care.firebasestorage.app` |

### 플랫폼별 설정

| 플랫폼 | App ID | 설정 파일 |
|--------|--------|----------|
| Android | `1:854417470022:android:5c14ba7e839ba264959047` | `android/app/google-services.json` |
| iOS | `1:854417470022:ios:566d3bb7b8e2c558959047` | `ios/Runner/GoogleService-Info.plist` |
| macOS | 미설정 | `UnsupportedError` 발생 |
| Web | 미설정 | - |

### 사용 중인 Firebase 서비스

```yaml
firebase_core: ^3.12.1        # 코어 초기화
firebase_messaging: ^15.2.4    # FCM 푸시 알림
firebase_analytics: ^11.4.2    # 이벤트 분석
```

### Dart 설정 파일

- `lib/firebase_options.dart` — `flutterfire configure`로 생성
- 새 플랫폼 추가 시 `flutterfire configure` 재실행 필요

---

## 8. 플랫폼별 설정 매트릭스

### iOS

| 설정 | 파일 | 상태 |
|------|------|------|
| Google URL Scheme | `ios/Runner/Info.plist` | 설정됨 |
| Kakao URL Scheme | `ios/Runner/Info.plist` | 설정됨 |
| Kakao Query Schemes | `ios/Runner/Info.plist` | 설정됨 |
| Deep Link (perchcare://) | `ios/Runner/Info.plist` | 설정됨 |
| Apple Sign In Capability | Xcode | 설정 필요 |
| Firebase | `GoogleService-Info.plist` | 설정됨 |
| Bundle ID | `com.perch.perchCare` | - |

### Android

| 설정 | 파일 | 상태 |
|------|------|------|
| Kakao AuthCodeHandler | `AndroidManifest.xml` | 설정됨 |
| Deep Link (perchcare://) | `AndroidManifest.xml` | 설정됨 |
| Firebase | `google-services.json` | 설정됨 |
| Package Name | `com.perch.perch_care` | - |

### macOS

| 설정 | 파일 | 상태 |
|------|------|------|
| Deep Link (perchcare://) | `macos/Runner/Info.plist` | 설정됨 |
| Firebase | - | 미설정 |
| OAuth | - | 미설정 |

---

## 9. 서비스 초기화 순서

`lib/src/screens/splash/splash_screen.dart`에서 다음 순서로 초기화:

```
1. [직렬] dotenv.load('.env')          → API_BASE_URL 로드
        ↓
2. [병렬] Future.wait([
            _initTokenService(),       → Secure Storage에서 토큰 복원
            _initGoogleSignIn(),       → Google SDK 초기화
            _initLocalImageStorage(),  → 이미지 캐시 준비
          ])
        ↓
3. [직렬] ApiClient.initialize()       → ApiClient 싱글톤 생성
        ↓
4. [판단] TokenService.isLoggedIn?
          → true:  /home 이동
          → false: /onboarding 이동
```

- TokenService 초기화 실패 시 3회 재시도 (지수 백오프)
- 개별 서비스 초기화 실패는 로그만 남기고 앱 기동 차단하지 않음

---

## 10. Auth Service 구현 상세

### 파일: `lib/src/services/auth/auth_service.dart`

### OAuth 메서드

```dart
// Google — id_token 전송
Future<SocialLoginResult> signInWithGoogle({required String idToken})

// Apple — id_token + 사용자 정보 전송
Future<SocialLoginResult> signInWithApple({
  required String idToken,
  String? userIdentifier,
  String? fullName,
  String? email,
})

// Kakao — access_token 전송
Future<SocialLoginResult> signInWithKakao({required String accessToken})
```

### 로그인 결과 모델

```dart
class SocialLoginResult {
  final bool success;           // 로그인 성공 여부
  final bool signupRequired;    // 추가 회원가입 필요 여부
  final String? provider;       // 'google', 'apple', 'kakao'
  final String? providerId;     // 제공자별 사용자 ID
  final String? providerEmail;  // 제공자 이메일
}
```

### 인증 성공 후 처리

```dart
// 토큰 저장
await _tokenService.saveTokens(accessToken, refreshToken);

// FCM 푸시 알림 초기화
PushNotificationService.instance.initialize();

// 분석 이벤트 로깅
AnalyticsService.instance.logLogin(provider);
```

### 소셜 계정 연동 (사용자 설정)

```dart
// 계정 연동
Future<void> linkSocialAccount({
  required String provider,
  String? idToken,
  String? accessToken,
  String? providerId,
  String? providerEmail,
})

// 연동된 계정 조회
Future<List<LinkedSocialAccount>> getSocialAccounts()

// 계정 연동 해제
Future<void> unlinkSocialAccount(String provider)
```

---

## 11. 라우터 인증 가드

### 파일: `lib/src/router/app_router.dart`

### 보호 로직

```dart
redirect: (context, state) {
  // 1. Splash는 항상 허용
  if (currentPath == RoutePaths.splash) return null;

  // 2. TokenService 미초기화 시 → Splash로 리다이렉트
  if (!TokenService.instance.isInitialized) return RoutePaths.splash;

  final isLoggedIn = TokenService.instance.isLoggedIn;

  // 3. 미로그인 + 비공개 경로 → Login으로 리다이렉트
  if (!isLoggedIn && !isPublicRoute) return RoutePaths.login;

  // 4. 로그인 상태 + 인증 화면 접근 → Home으로 리다이렉트
  if (isLoggedIn && isAuthScreen) return RoutePaths.home;

  return null; // 접근 허용
}
```

### 공개 경로 (로그인 불필요)

- `/` (Splash)
- `/onboarding`
- `/login`
- `/signup`
- `/email-login`
- `/forgot-password/*`

---

## 12. 환경 변수

### `.env.example`

```
API_BASE_URL=https://your-domain.com/api/v1
```

### 사용 방식

- `splash_screen.dart`에서 `flutter_dotenv`로 로드
- `Environment.apiBaseUrl`로 접근
- 미설정 시 런타임 `StateError` 발생

---

## 13. 개발자 세팅 체크리스트

### 최초 실행 전 필수

- [ ] `.env.example`을 `.env`로 복사 후 `API_BASE_URL` 설정
- [ ] 백엔드 API 서버 실행 확인
- [ ] `flutter pub get` 실행

### Google OAuth

- [ ] Google Cloud Console에서 OAuth 동의 화면 구성
- [ ] iOS 클라이언트 ID 생성 (번들 ID: `com.perch.perchCare`)
- [ ] Android 클라이언트 ID 생성 (패키지명: `com.perch.perch_care`, SHA-1 키 해시 등록)
- [ ] Server Client ID 확인 (백엔드 토큰 검증용)

### Apple Sign In

- [ ] Apple Developer 계정에서 App ID에 "Sign in with Apple" 활성화
- [ ] Xcode → Signing & Capabilities → "Sign in with Apple" 추가
- [ ] Provisioning Profile 재생성 및 다운로드

### Kakao OAuth

- [ ] Kakao Developers에서 앱 생성
- [ ] 네이티브 앱 키 확인: `23f9d1f1b79cea8566c54a44ba33b463`
- [ ] 플랫폼 등록 (iOS 번들 ID, Android 패키지명 + 키 해시)
- [ ] 카카오 로그인 활성화
- [ ] 동의 항목 설정 (이메일, 프로필)

### Firebase

- [ ] iOS: `GoogleService-Info.plist` 존재 확인
- [ ] Android: `google-services.json` 존재 확인
- [ ] 새 플랫폼 추가 시 `flutterfire configure` 실행

---

## 14. 의존성 목록

```yaml
# OAuth
google_sign_in: ^7.2.0             # Google Sign In
sign_in_with_apple: ^7.0.1         # Apple Sign In

# Firebase
firebase_core: ^3.12.1             # Firebase 코어
firebase_messaging: ^15.2.4        # FCM 푸시 알림
firebase_analytics: ^11.4.2        # Analytics

# 토큰/보안 저장소
flutter_secure_storage: ^10.0.0    # Keychain / EncryptedSharedPrefs

# 환경/설정
flutter_dotenv: ^5.1.0             # .env 파일 로드

# HTTP
http: ^1.2.2                       # HTTP 클라이언트

# 네비게이션
go_router: ^14.6.2                 # 라우팅 + 인증 가드

# 로컬 데이터
shared_preferences: ^2.3.2         # SharedPreferences
sqflite: ^2.4.1                    # SQLite 로컬 DB
```
