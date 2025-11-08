# Supabase 초기 설정 가이드

## 1. 프로젝트 생성
- [Supabase 콘솔](https://supabase.com)에 로그인한 뒤 새 프로젝트를 만든다.
- `Project URL`과 `anon/public API key`를 복사해서 `./.env`에 입력한다.
  ```bash
  cp .env.example .env
  ```
  ```
  SUPABASE_URL=https://<project-ref>.supabase.co
  SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
  ```

## 2. Flutter 환경 설정
- 의존성 설치: `flutter pub get`
- 앱 시작 전에 `.env`를 읽고 Supabase를 초기화하도록 `lib/main.dart`가 구성돼 있다.
- 키가 비어 있으면 런타임에서 `StateError`가 발생하므로 반드시 값을 채운다.

## 3. 인증 정책
- Supabase 대시보드 > **Authentication** > **Providers**에서 Email provider를 허용한다.
- 이메일 인증 메일의 리다이렉트 URL이 필요하면 `Authentication > URL Configuration`에 앱 도메인(또는 개발용 Deep Link)을 등록한다.
- 비밀번호 정책은 `Authentication > Policies`에서 길이/복잡도를 설정할 수 있다.

## 4. Google / Apple OAuth 준비
1. Supabase에서 각 OAuth 제공자를 활성화하고 Client ID / Secret을 등록한다.
2. Flutter 앱에서는 `supabase_flutter`의 `signInWithOAuth` 메서드를 호출하면 된다.
   ```dart
   await Supabase.instance.client.auth.signInWithOAuth(
     Provider.google,
     redirectTo: '<scheme>://auth-callback',
   );
   ```
3. iOS/Android 별로 커스텀 URL 스킴/deep link를 설정해야 하며, 설정값은 Supabase 콘솔의 리다이렉트 URL과 일치해야 한다.

## 5. 로컬 개발 팁
- `supabase start`를 사용하면 로컬 Docker로 Supabase를 띄울 수 있다. (별도 설치 필요)
- Staging/Production 키는 `.env.staging`, `.env.production` 등으로 분리하고 빌드 스크립트에서 선택적으로 로드하는 방식을 추천한다.

## 6. 이메일 인증용 딥링크 구성
- 이 앱은 `perchcare://auth-callback` 스킴을 사용한다.
  - iOS: `ios/Runner/Info.plist`
  - macOS: `macos/Runner/Info.plist`
  - Android: `android/app/src/main/AndroidManifest.xml`
  - Supabase 콘솔 → **Authentication → URL Configuration** → Redirect URLs에 동일한 스킴을 등록한다.
  - `AuthService`가 이메일/Google/Apple 가입 모두에 `perchcare://auth-callback`을 전달해 일관된 딥링크를 사용한다.
  - 앱이 열리면 `supabase.auth.onAuthStateChange` 구독을 통해 인증 완료 이벤트를 감지하고 후속 화면으로 안내한다.

## 7. Google / Apple OAuth 필수 설정
- Supabase → **Authentication → Providers**에서 Google과 Apple을 각각 활성화한다.
- Google:
  1. Google Cloud Console에서 OAuth 동의 화면을 설정하고 Web Client를 생성한다.
  2. 승인된 JavaScript 원본: `https://<project-ref>.supabase.co`
  3. 승인된 redirect URI: `https://<project-ref>.supabase.co/auth/v1/callback`
  4. 발급된 Client ID/Secret을 Supabase에 입력.
- Apple:
  1. Apple Developer 계정에서 “Sign in with Apple” 서비스 설정 후 Client ID, Team ID, Key ID, Private Key를 준비한다.
  2. Supabase 콘솔의 Apple provider 설정에 위 값을 입력한다.
  3. iOS/macOS 번들 ID와 일치하는 “Service ID”를 사용해야 하며, redirect URI도 `https://<project-ref>.supabase.co/auth/v1/callback`.
