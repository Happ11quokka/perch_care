# 소셜 로그인 SDK 연동 (Google, Apple, Kakao)

**날짜**: 2026-01-29
**파일**:
- [lib/main.dart](../../lib/main.dart)
- [lib/src/services/auth/auth_service.dart](../../lib/src/services/auth/auth_service.dart)
- [lib/src/screens/login/login_screen.dart](../../lib/src/screens/login/login_screen.dart)
- [lib/src/screens/login/email_login_screen.dart](../../lib/src/screens/login/email_login_screen.dart)
- [ios/Runner/Info.plist](../../ios/Runner/Info.plist)
- [ios/Runner/GoogleService-Info.plist](../../ios/Runner/GoogleService-Info.plist)
- [ios/Podfile](../../ios/Podfile)
- [android/app/src/main/AndroidManifest.xml](../../android/app/src/main/AndroidManifest.xml)
- [pubspec.yaml](../../pubspec.yaml)

## 구현 목표
- Google, Apple, Kakao 3개 소셜 로그인 SDK를 Flutter 앱에 통합.
- 각 플랫폼 SDK에서 토큰을 획득한 뒤 FastAPI 백엔드(`/auth/oauth/{provider}`)로 전달하여 JWT를 발급받는 구조.
- iOS/Android 양 플랫폼에서 동작하도록 네이티브 설정 구성.

## 주요 변경 사항

### 1. Google Sign-In (`google_sign_in: ^7.2.0`)

- **SDK 초기화**: `main.dart`에서 앱 시작 시 `GoogleSignIn.instance.initialize(clientId:)`를 1회 호출. v7 API는 `initialize()`를 앱 라이프사이클 내 1회만 호출하도록 요구하며, 이후 `authenticate()`로 로그인 수행.
- **iOS 설정**: `GoogleService-Info.plist`를 `ios/Runner/`에 배치, `Info.plist`에 reversed client ID URL scheme 등록 (`com.googleusercontent.apps.351000470573-...`).
- **OAuth 클라이언트**: Google Cloud Console에서 iOS/Android 각각 OAuth 클라이언트 생성.
  - iOS Client ID: `351000470573-9cu20o306ho5jepgee2b474jnd0ah08b`
  - Android Client ID: `351000470573-ivirja6bvfpqk0rsg1shd048erdk1tv4`
  - Android SHA-1: `7C:7E:69:2E:F9:5D:4B:65:7F:78:3C:E7:8F:2C:07:A2:C9:75:9D:16`
- **인증 흐름**: `authenticate()` → `account.authentication.idToken` → 백엔드 `/auth/oauth/google`로 `id_token` 전송.

### 2. Apple Sign-In (`sign_in_with_apple: ^7.0.1`)

- **SDK 설정**: 별도 파일 설정 불필요. Xcode에서 "Sign In with Apple" Capability 추가만 필요.
- **인증 흐름**: `SignInWithApple.getAppleIDCredential(scopes: [email])` → `credential.identityToken` → 백엔드 `/auth/oauth/apple`로 `id_token` 전송.
- **제한 사항**: iOS 시뮬레이터에서는 테스트 불가, 실기기에서만 동작.

### 3. Kakao Login (`kakao_flutter_sdk_user: 1.9.5`)

- **SDK 초기화**: `main.dart`에서 `KakaoSdk.init(nativeAppKey: '23f9d1f1b79cea8566c54a44ba33b463')` 호출.
- **iOS 설정**: `Info.plist`에 Kakao URL scheme (`kakao23f9d1f1...`) 및 `LSApplicationQueriesSchemes` (`kakaokompassauth`, `kakaolink`, `kakaoplus`) 등록.
- **Android 설정**: `AndroidManifest.xml`에 `AuthCodeHandlerActivity` 추가, scheme `kakao23f9d1f1...` 등록.
- **Kakao Developers 콘솔 설정**:
  - 앱 ID: 1377279 (PerchCare)
  - 네이티브 앱 키: `23f9d1f1b79cea8566c54a44ba33b463`
  - Android 패키지명: `com.perch.perch_care`, 키 해시: `fH5pLvldS2V/eDznjywHosl1nRY=`
  - iOS 번들 ID: `com.perch.perchCare`
  - 카카오 로그인 활성화 필요 (제품 설정 > 카카오 로그인)
- **인증 흐름**: 카카오톡 설치 여부에 따라 `loginWithKakaoTalk()` 또는 `loginWithKakaoAccount()` 분기 → `token.accessToken` → 백엔드 `/auth/oauth/kakao`로 `access_token` 전송.
- **버전 고정 사유**: v1.10.0이 Flutter 3.32의 `widget_previews.dart` 임포트 오류를 발생시켜 1.9.5로 다운그레이드.

### 4. auth_service.dart 변경

- `signInWithKakao()` 파라미터를 `authorizationCode` → `accessToken`으로 변경. Kakao Flutter SDK는 네이티브 앱에서 전체 토큰 교환을 처리하므로 access_token을 직접 백엔드로 전달.

### 5. 플랫폼 빌드 설정

- iOS `Podfile`: 최소 배포 버전을 13.0으로 활성화 (Kakao SDK 요구사항).

## 아키텍처 요약

```
┌─────────────────┐     ┌──────────────┐     ┌──────────────┐
│  Flutter App     │     │  SDK          │     │  FastAPI      │
│                  │     │              │     │  Backend      │
│  Login Button    │────▶│  Google SDK   │     │              │
│  pressed         │     │  Apple SDK    │     │              │
│                  │     │  Kakao SDK    │     │              │
│                  │     │              │     │              │
│  Receive token   │◀────│  id_token /   │     │              │
│                  │     │  access_token │     │              │
│                  │     └──────────────┘     │              │
│  Send to backend │────────────────────────▶│ /auth/oauth/* │
│                  │                          │              │
│  Save JWT        │◀────────────────────────│ access_token  │
│                  │                          │ refresh_token │
└─────────────────┘                          └──────────────┘
```

- Google/Apple: `id_token` (JWT) → 백엔드에서 검증 후 자체 JWT 발급
- Kakao: `access_token` (OAuth) → 백엔드에서 Kakao API로 사용자 정보 조회 후 자체 JWT 발급

## 테스트 메모
- iOS 시뮬레이터(iPhone 15 Pro Max)에서 빌드 및 실행 확인 완료.
- Kakao 로그인: 카카오계정 웹 로그인 화면 정상 표시 확인.
- Apple 로그인: 시뮬레이터 제한으로 실기기 테스트 필요.
- Google 로그인: `initialize()` 중복 호출 및 `clientId` 미전달 이슈 수정 후 정상 동작.
- 백엔드 API 연동은 FastAPI 서버 준비 후 E2E 테스트 필요.
