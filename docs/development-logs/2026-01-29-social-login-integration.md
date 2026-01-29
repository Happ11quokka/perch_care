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

---

## 버그 수정: Google OAuth provider_id 저장 오류

**날짜**: 2026-01-29
**수정 파일**:
- [backend/app/utils/security.py](../../backend/app/utils/security.py)
- [backend/app/routers/auth.py](../../backend/app/routers/auth.py)
- [backend/app/routers/users.py](../../backend/app/routers/users.py)
- [backend/app/schemas/user.py](../../backend/app/schemas/user.py)
- [backend/requirements.txt](../../backend/requirements.txt)
- [backend/.env](../../backend/.env)
- [lib/src/services/auth/auth_service.dart](../../lib/src/services/auth/auth_service.dart)
- [lib/src/screens/profile/profile_screen.dart](../../lib/src/screens/profile/profile_screen.dart)

### 증상

Google 소셜 로그인 및 계정 연동 시 DB INSERT 에러 발생:

```
asyncpg.exceptions.StringDataRightTruncationError:
  value too long for type character varying(255)
```

`social_accounts` 테이블의 `provider_id` 컬럼(`VARCHAR(255)`)에 Google ID Token(JWT, 1000+ chars)이 그대로 저장되고 있었음.

### 원인

두 곳에서 동일한 문제가 발생:

1. **OAuth 로그인 (`/auth/oauth/google`)**: `auth.py`에서 `request.id_token`을 검증 없이 `provider_id`로 사용.
   ```python
   # 수정 전 (auth.py)
   provider_id = request.id_token or request.authorization_code or ""
   ```

2. **소셜 계정 연동 (`/users/me/social-accounts`)**: Flutter `profile_screen.dart`에서 Google `idToken` (JWT 전체)을 `providerId`로 전달하고, 백엔드 `users.py`가 검증 없이 그대로 DB에 저장.
   ```dart
   // 수정 전 (profile_screen.dart)
   await _authService.linkSocialAccount(
     provider: 'google',
     providerId: idToken,  // JWT 전체 (1000+ chars)
   );
   ```

### 수정 내용

#### 1. Google ID Token 서버 검증 함수 추가 (`security.py`)

`google-auth` 라이브러리를 사용하여 ID Token을 검증하고 `sub` claim(Google 유저 고유 ID, 숫자 문자열)을 추출하는 함수 추가:

```python
from google.oauth2 import id_token as google_id_token
from google.auth.transport import requests as google_requests

def verify_google_id_token(token: str) -> dict | None:
    idinfo = google_id_token.verify_oauth2_token(
        token,
        google_requests.Request(),
        audience=settings.google_client_id,  # 우리 앱 토큰만 허용
    )
    return idinfo  # {"sub": "1234567890", "email": "...", ...}
```

- `audience` 파라미터로 우리 앱의 Google Client ID만 허용 (타 앱 토큰 차단).

#### 2. OAuth 로그인 엔드포인트 수정 (`auth.py`)

```python
# 수정 후
if provider == "google" and request.id_token:
    google_info = verify_google_id_token(request.id_token)
    if not google_info:
        raise HTTPException(status_code=401, detail="Invalid Google ID token")
    provider_id = google_info["sub"]  # 짧은 숫자 ID
    email = email or google_info.get("email")
```

#### 3. 소셜 계정 연동 엔드포인트 수정 (`users.py`)

연동 API에서도 동일하게 `id_token`을 받아 서버에서 검증:

```python
if request.provider == "google" and request.id_token:
    google_info = verify_google_id_token(request.id_token)
    provider_id = google_info["sub"]
    provider_email = provider_email or google_info.get("email")
```

#### 4. 스키마 변경 (`user.py`)

`SocialAccountLinkRequest`에 `id_token` 필드 추가:

```python
class SocialAccountLinkRequest(BaseModel):
    provider: str
    id_token: str | None = None       # 추가
    provider_id: str | None = None
    provider_email: str | None = None
```

#### 5. Flutter 클라이언트 수정

`auth_service.dart`의 `linkSocialAccount`에 `idToken` 파라미터 추가, `profile_screen.dart`에서 Google/Apple 연동 시 `idToken`으로 전송:

```dart
// 수정 후 (profile_screen.dart)
await _authService.linkSocialAccount(
  provider: 'google',
  idToken: idToken,  // provider_id 대신 id_token으로 전송
);
```

#### 6. 의존성 및 환경 설정

- `requirements.txt`에 `google-auth==2.37.0`, `requests==2.32.3` 추가.
- `.env`에 `GOOGLE_CLIENT_ID` 값 설정 (iOS `GoogleService-Info.plist`의 `CLIENT_ID` 값 사용).

### 데이터 흐름 (수정 후)

```
Flutter App                          FastAPI Backend
─────────────────────────────────────────────────────
Google SDK → idToken (JWT)
                    ──id_token──▶  verify_google_id_token()
                                   ├─ JWT 서명 검증
                                   ├─ audience(Client ID) 검증
                                   └─ sub claim 추출 ("1234567890")
                                          │
                                   provider_id = "1234567890"
                                          │
                                   INSERT INTO social_accounts
                                   (provider_id = "1234567890") ✅
```

### 핵심 교훈

- 클라이언트에서 받은 OAuth 토큰은 **반드시 서버에서 검증** 후 사용해야 한다.
- `provider_id`에는 provider가 발급한 **유저 고유 식별자**를 저장해야 하며, 토큰 자체를 저장하면 안 된다.
- Google의 경우 `id_token`(JWT)의 `sub` claim이 유저 고유 ID이다.
- `audience` 검증을 빠뜨리면 다른 앱에서 발급된 Google 토큰으로도 인증이 통과되는 보안 취약점이 생긴다.
