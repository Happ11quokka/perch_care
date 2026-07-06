# Stage 4A — Auth 도메인 MVVM Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 인증 관련 8화면 + 외부 콜러(profile_screen 7건, pet_profile_screen 1건)의 `AuthService.instance` 직접 호출을 `AuthRepository`/`AuthViewModel` 경유로 전환하고, 두 로그인 화면에 복붙된 ~120줄(소셜 로그인 핸들러 + hasPets 라우팅)을 일원화한다.

**Architecture:** `AuthRepository`(abstract+impl)가 `AuthService`를 래핑 — 단, `signOut`/`deleteAccount`의 7개 서비스 싱글턴 정리 로직은 **AuthService 내부에 그대로 두고 Repository는 위임만** 한다(순환 의존 회피). 플랫폼 소셜 SDK 호출(GoogleSignIn/SignInWithApple)은 Repository로 내려 "사용자 취소"를 결과 타입으로 흡수. 공유 로그인 오케스트레이션(소셜 end-to-end + 이메일 + 로그인 후 라우팅 + 로그아웃)은 `AuthViewModel`이 소유하고 두 로그인 화면이 공유. 나머지 화면(signup/forgot/profile_setup/profile/pet_profile)은 Repository를 직접 `ref.read`.

**Tech Stack:** Flutter, flutter_riverpod (AsyncNotifier), google_sign_in 7.x, sign_in_with_apple, mocktail + ProviderContainer.

## Global Constraints

- **behavior-preserving**: UI·네트워크·에러 메시지·라우팅·토큰 흐름 불변(명시된 개선 제외).
- **hasPets tri-state 보존**: `true`=펫 있음→home, `false`=확정 없음→onboarding(profileSetup), `null`=확인 실패→**home(안전 분기)**. false와 null을 합치면 기존 사용자가 onboarding으로 잘못 빠지는 회귀 — 반드시 3분기 유지 + 테스트 고정.
- **signOut/deleteAccount 정리 로직은 AuthService에 유지** — Repository는 `service.signOut()`/`service.deleteAccount()` 위임만. 7개 서비스 싱글턴 정리를 Repository/VM으로 옮기지 않는다(순환 의존·범위 폭발 회피).
- **signOut vs deleteAccount의 FCM 정리 비대칭은 보존**(deleteAccount는 FCM 토큰 삭제 없음 — 기존 동작). 통일은 별도 결정/커밋.
- **CoachMarkService/AnalyticsService는 View/VM 직접 호출 허용**(cross-cutting).
- **AsyncViewModel base에는 runLoad만 존재**(runAction 없음). 필요 시 AsyncNotifier 직접 상속.
- **토큰 갱신은 ApiClient 내장 인프라**(tryRefreshToken/single-flight) — Repository가 감싸지 않는다.
- **완료 게이트(매 커밋)**: `flutter analyze` 신규 0 + `flutter test` 통과.
- 커밋 푸터:
  ```
  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA
  ```

## AuthService 공개 API (래핑 대상 — 실코드 확인 후 정확히)

`signUpWithEmail({email,password,nickname?,marketingAgreed})→void` · `signInWithEmailPassword({email,password})→void`(hasPets는 `_lastHasPets` 사이드채널) · `signInWithGoogle({idToken})→SocialLoginResult` · `signInWithApple({idToken,userIdentifier?,fullName?,email?})→SocialLoginResult` · `signOut()→void` · `resetPassword(email)→void` · `resetPasswordByPhone(phone)→void` · `verifyResetCode(identifier,code,{method='email'})→void` · `updatePassword({identifier,code,newPassword,method='email'})→void` · `getProfile()→Map<String,dynamic>?` · `updateProfile({nickname?,avatarUrl?})→void` · `hasPets()→bool?`(tri-state) · `deleteAccount()→void` · `linkSocialAccount({provider,idToken?,accessToken?,providerId?,providerEmail?})→void` · `getSocialAccounts()→List<LinkedSocialAccount>` · `unlinkSocialAccount(provider)→void`. DTO: `SocialLoginResult{success,signupRequired,provider?,providerId?,providerEmail?,hasPets}`(팩토리 authenticated/signupNeeded), `LinkedSocialAccount{provider,providerEmail?,createdAt}`.

---

## File Structure

**신규:** `lib/src/repositories/auth_repository.dart`, `lib/src/view_models/auth/auth_view_model.dart`, `lib/src/view_models/auth/post_login_destination.dart`(enum + 순수 매핑), 각 테스트.
**수정:** `repository_providers.dart`, 8 auth 화면, `profile_screen.dart`(auth 부분), `pet_profile_screen.dart`, `auth_actions.dart`(performLogout 제거/승격), `active_pet_view_model.dart`(주석 갱신).

---

## Task 1: AuthRepository 신설 (전체 AuthService 래핑 + LoginOutcome DTO)

**Files:** Create `lib/src/repositories/auth_repository.dart`, `test/repositories/auth_repository_test.dart`; Modify `lib/src/providers/repository_providers.dart`.

**Interfaces (Produces):**
```dart
/// 로그인 결과 — 이메일/소셜 공통. hasPets를 결과에 실어 라우팅 재조회 제거.
sealed class LoginOutcome {}
class LoginAuthenticated extends LoginOutcome { LoginAuthenticated(this.hasPets); final bool? hasPets; }
class LoginSignupRequired extends LoginOutcome { LoginSignupRequired({required this.provider, this.providerId, this.providerEmail}); final String provider; final String? providerId; final String? providerEmail; }

abstract class AuthRepository {
  bool get isLoggedIn;
  Future<LoginOutcome> signInWithEmail({required String email, required String password});
  Future<void> signUpWithEmail({required String email, required String password, String? nickname, bool marketingAgreed = false});
  Future<void> discardSession();                       // signup '나중에/확인' — TokenService.clearTokens 흡수
  Future<LoginOutcome> signInWithGoogle(GoogleCredential credential);
  Future<LoginOutcome> signInWithApple(AppleCredential credential);
  Future<void> signOut();
  Future<void> deleteAccount();
  Future<void> resetPassword(String email);
  Future<void> verifyResetCode(String identifier, String code, {String method});
  Future<void> updatePassword({required String identifier, required String code, required String newPassword, String method});
  Future<Map<String, dynamic>?> getProfile();
  Future<void> updateProfile({String? nickname, String? avatarUrl});
  Future<bool?> hasPets();
  Future<void> linkSocialAccount({required String provider, String? idToken, String? accessToken, String? providerId, String? providerEmail});
  Future<List<LinkedSocialAccount>> getSocialAccounts();
  Future<void> unlinkSocialAccount(String provider);
}
```
- `GoogleCredential`/`AppleCredential`는 Task 2에서 정의 — Task 1에서는 `signInWithGoogle/Apple`를 **idToken 기반 임시 시그니처**로 두지 말고 Task 2와 함께 확정한다. **Task 1에서는 credential 타입을 Task 2가 정의할 것으로 전제하고, Task 1은 idToken을 직접 받는 형태로 먼저 구현**: `signInWithGoogle({required String idToken})`, `signInWithApple({required String idToken, String? userIdentifier, String? fullName, String? email})` — Task 2에서 credential 획득 계층 추가 시 시그니처를 credential 객체로 승격. (즉 Task 1은 AuthService 시그니처와 1:1.)
- `signInWithEmail`: `service.signInWithEmailPassword(...)` 호출 후 `service.hasPets()` 결과로 `LoginAuthenticated(hasPets)` 반환.
- `signInWithGoogle/Apple`: `service.signInWithGoogle/Apple(...)`의 `SocialLoginResult`를 `LoginOutcome`으로 매핑(signupRequired→LoginSignupRequired, else→LoginAuthenticated(result.hasPets)).
- `discardSession`: `TokenService.instance.clearTokens()` 위임.
- 생성자 주입: `AuthRepositoryImpl({AuthService? service, TokenService? tokenService})`.
- `final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepositoryImpl());`

- [ ] **Step 1:** `lib/src/services/auth/auth_service.dart` + `token_service.dart` 정독 — 정확한 시그니처/DTO 확인. 특히 `signInWithEmailPassword`가 void이고 hasPets가 `_lastHasPets`+`hasPets()`로 나오는지 확인.
- [ ] **Step 2: 실패 테스트** `test/repositories/auth_repository_test.dart` (mocktail MockAuthService + MockTokenService): signInWithEmail이 service 호출 후 hasPets를 LoginAuthenticated로 반환; signInWithGoogle의 signupRequired→LoginSignupRequired 매핑; discardSession→clearTokens 위임; signOut/deleteAccount/reset/verify/updatePassword/getProfile/updateProfile/hasPets/link/getSocial/unlink 위임. **hasPets tri-state 3케이스(true/false/null) 반환 고정 테스트.**
- [ ] **Step 3:** RED 확인 → 구현 → provider 등록.
- [ ] **Step 4:** `flutter test test/repositories/auth_repository_test.dart` PASS + `flutter analyze` clean + `flutter test`(full) 통과.
- [ ] **Step 5: Commit** `|FEAT| AuthRepository 신설 — AuthService 래핑(로그인/가입/소셜/재설정/프로필/hasPets/탈퇴/연동) + LoginOutcome DTO`

---

## Task 2: 소셜 credential 획득을 Repository로 이관

**근거:** GoogleSignIn.instance.authenticate()·SignInWithApple.getAppleIDCredential() SDK 호출이 login_screen(L64-65,95)·email_login_screen(L580-581,611)에 복붙. "사용자 취소"(GoogleSignInExceptionCode.canceled / AuthorizationErrorCode.canceled) 처리도 동일. 이를 Repository로 내려 취소를 결과로 흡수.

**Files:** Modify `lib/src/repositories/auth_repository.dart` (+test).

**Interfaces (Produces):**
```dart
/// 소셜 자격 획득 결과 — 취소는 예외가 아닌 null-형 결과로 흡수.
enum SocialLoginStep { obtainedCredential, canceled }
// AuthRepository에 추가:
Future<LoginOutcome?> loginWithGoogle();  // SDK 자격획득 → signInWithGoogle. 사용자 취소 시 null
Future<LoginOutcome?> loginWithApple();   // 동일. 취소 시 null
```
- `loginWithGoogle()`: `GoogleSignIn.instance.authenticate()`로 idToken 획득(취소 예외 catch→null 반환) → `signInWithGoogle(idToken:)` → LoginOutcome. `loginWithApple()`: `SignInWithApple.getAppleIDCredential(scopes:[email,fullName])`(취소 catch→null) → `signInWithApple(...)`.
- 기존 idToken 기반 `signInWithGoogle/Apple`는 유지(Impl 내부에서 재사용). 화면은 `loginWithGoogle/Apple`만 호출.
- **테스트 한계:** SDK 정적 호출은 mock 불가 → `loginWithGoogle/Apple`의 순수 단위 테스트는 생략하고, credential 획득 이후 경로(signInWithGoogle idToken)만 테스트. 보고에 명시.

- [ ] **Step 1:** login_screen/email_login_screen의 `_handleGoogleLogin`/`_handleAppleLogin` 정독 — SDK 호출·취소 처리·idToken 추출 로직 확인.
- [ ] **Step 2:** Impl에 loginWithGoogle/Apple 추가(SDK 호출 + 취소→null + idToken 경로 재사용). abstract에도 선언.
- [ ] **Step 3:** `flutter analyze` clean + `flutter test` 통과(신규 순수 테스트는 idToken 경로만).
- [ ] **Step 4: Commit** `|FEAT| AuthRepository — 소셜 SDK 자격획득 이관(loginWithGoogle/Apple, 취소는 null 흡수)`

---

## Task 3: AuthViewModel + PostLoginDestination

**Files:** Create `lib/src/view_models/auth/post_login_destination.dart`, `lib/src/view_models/auth/auth_view_model.dart`, `test/view_models/auth/auth_view_model_test.dart`.

**Interfaces (Produces):**
```dart
// post_login_destination.dart
enum PostLoginDestination { home, onboarding }
/// hasPets tri-state → 목적지. false만 onboarding, true/null은 home.
PostLoginDestination destinationForHasPets(bool? hasPets) =>
    hasPets == false ? PostLoginDestination.onboarding : PostLoginDestination.home;

// auth_view_model.dart
class AuthViewModel extends AsyncNotifier<void> {
  Future<LoginOutcome> signInWithEmail({required String email, required String password});
  Future<LoginOutcome?> loginWithGoogle();   // null = 사용자 취소
  Future<LoginOutcome?> loginWithApple();
  Future<void> logout();                      // repo.signOut() + ref.invalidate(activePet/petList)
}
final authViewModelProvider = AsyncNotifierProvider<AuthViewModel, void>(AuthViewModel.new);
```
- 액션은 `runLoad`형 전체교체가 아니라 명령형 — AsyncNotifier<void> 직접 상속, `state = AsyncLoading()` → try → `AsyncData(null)` / `AsyncError`+rethrow 패턴(WeightAddViewModel 참고). 화면은 결과 DTO로 라우팅.
- `logout()`: `ref.read(authRepositoryProvider).signOut()` 후 `ref.invalidate(activePetViewModelProvider)`, `ref.invalidate(petListViewModelProvider)`. (Stage 3에서 bhiProvider 삭제됨 — bhi invalidate 없음.)
- `destinationForHasPets`는 순수 함수 — 별도 단위 테스트로 tri-state 3케이스 고정.

- [ ] **Step 1: 실패 테스트** `test/view_models/auth/auth_view_model_test.dart` (Mock AuthRepository): signInWithEmail이 repo 위임+결과 반환; loginWithGoogle이 취소 시 null 전파; logout이 repo.signOut + invalidate. + `post_login_destination` 3케이스(true→home, false→onboarding, null→home).
- [ ] **Step 2:** RED → 구현 → PASS.
- [ ] **Step 3:** `flutter analyze` clean + `flutter test` 통과.
- [ ] **Step 4: Commit** `|FEAT| AuthViewModel + PostLoginDestination — 소셜/이메일 로그인·로그아웃·hasPets 라우팅 일원화`

---

## Task 4: login_screen + email_login_screen 전환 (중복 제거)

**Files:** Modify `lib/src/screens/login/login_screen.dart`, `lib/src/screens/login/email_login_screen.dart`.

**전환 규칙:**
1. `AuthService _authService` 필드 제거. 소셜/이메일 로그인은 `ref.read(authViewModelProvider.notifier)` 경유.
2. `_handleGoogleLogin`/`_handleAppleLogin`의 SDK 호출부 → `ref.read(authViewModelProvider.notifier).loginWithGoogle()/loginWithApple()`. 반환 `LoginOutcome?`가 null이면(사용자 취소) 조용히 종료(기존 취소 UX 보존).
3. `_handleSocialLoginResult` → `LoginOutcome` 분기: `LoginSignupRequired`면 signup으로(provider 정보 전달, 기존 흐름), `LoginAuthenticated`면 `_navigateAfterLogin(outcome.hasPets)`.
4. `_navigateAfterLogin`/hasPets 분기 → `destinationForHasPets(hasPets)` 사용: `PostLoginDestination.onboarding`→`goNamed(profileSetup)`, `home`→`goNamed(home)`. `_hasNavigatedAfterLogin` 재진입 가드 유지.
5. 이메일 로그인(email_login L560)은 `authViewModelProvider.notifier.signInWithEmail(...)` → 결과로 라우팅(hasPets 재조회 없음).
6. `_isGoogleLoading`/`_isAppleLoading`/`_isLoading` 등 View-local 로딩·포커스·컨트롤러 상태는 유지. 에러 처리(ErrorHandler.getUserMessage) 유지.
7. **중복 제거 확인:** 두 화면의 소셜 핸들러가 이제 VM 호출 + 결과 분기로 축소돼야 함(각 ~30줄 → 몇 줄).

- [ ] **Step 1:** 두 화면 정독 — 특히 login L33-134, email_login L81-104·560·574-650.
- [ ] **Step 2:** 규칙 1-7 적용. **behavior-preserving**: 취소 UX·에러 메시지·재진입 가드·라우팅 목적지 동일.
- [ ] **Step 3:** `flutter analyze` 두 파일 clean. `grep -n "AuthService\|GoogleSignIn\|SignInWithApple" login_screen.dart email_login_screen.dart` → SDK/서비스 직접 참조 0(VM 경유). `flutter test` 통과.
- [ ] **Step 4: Commit** `|REFACTOR| login/email_login MVVM 전환 — AuthViewModel 경유, 소셜 핸들러·hasPets 라우팅 중복(~120줄) 제거`

---

## Task 5: signup_screen 전환

**Files:** Modify `lib/src/screens/signup/signup_screen.dart`.

**전환 규칙:**
1. `AuthService _authService` 필드 제거. `signUpWithEmail` → `ref.read(authRepositoryProvider).signUpWithEmail(...)`.
2. 가입완료 다이얼로그의 `TokenService.instance.clearTokens()`(L465·L482, 두 버튼 동일) → `ref.read(authRepositoryProvider).discardSession()`. (Repository가 흡수 — View가 TokenService 직접 만지는 유일 쓰기 지점 제거.)
3. View-local 로딩/약관동의/포커스/컨트롤러 유지. 에러 처리 유지.

- [ ] **Step 1:** signup_screen 정독(L434-517).
- [ ] **Step 2:** 적용.
- [ ] **Step 3:** `flutter analyze` clean. `grep -n "AuthService\|TokenService.instance" signup_screen.dart` → 0. `flutter test` 통과.
- [ ] **Step 4: Commit** `|REFACTOR| signup_screen MVVM 전환 — AuthRepository 경유(signUp/discardSession)`

---

## Task 6: forgot_password 3화면 전환 (thin)

**Files:** Modify `forgot_password_method_screen.dart`, `forgot_password_code_screen.dart`, `forgot_password_reset_screen.dart`.

**전환 규칙 (얇게):**
1. 각 화면 `AuthService _authService` 필드 제거. `resetPassword`/`verifyResetCode`/`updatePassword`/`resetPasswordByPhone` → `ref.read(authRepositoryProvider).<method>(...)`.
2. **View 고유 상태 유지**: forgot_code의 120초 Timer·자동제출(onChanged), forgot_reset의 obscure 토글 등은 그대로. ViewModel로 올리지 않는다(복잡도만 증가).
3. forgot_code/forgot_reset의 `ApiException`/`SocketException` 직접 분기(code:318-324, reset:365-371)는 **그대로 보존**(behavior-preserving; ErrorHandler 통일은 별도).
4. `resetPasswordByPhone`(code:338, dead path)도 Repository에 있으면 경유, 없으면 Repository에 추가(현재 method='email'만 진입하나 코드 보존).

- [ ] **Step 1:** 3화면 정독.
- [ ] **Step 2:** 적용. (resetPasswordByPhone이 AuthRepository에 없으면 Task 1 인터페이스에 추가 — abstract+impl+위임.)
- [ ] **Step 3:** `flutter analyze` 3파일 clean. `grep AuthService.instance` → 0. `flutter test` 통과.
- [ ] **Step 4: Commit** `|REFACTOR| forgot_password 3화면 MVVM 전환 — AuthRepository 경유(View 타이머/에러분기 보존)`

---

## Task 7: profile_setup 화면 전환

**Files:** Modify `lib/src/screens/profile_setup/profile_setup_screen.dart`. (profile_setup_complete_screen은 서비스 호출 0 — 미대상.)

**전환 규칙:**
1. `AuthService _authService` 필드 제거. `getProfile`(L72)·`updateProfile`(L702) → `ref.read(authRepositoryProvider)` 경유.
2. `TokenService.instance.userId`(L57·L587)와 `LocalImageStorageService`(L60·L589)는 **그대로 유지** — auth 범위 밖(userId는 이미지 저장 키, image storage는 Stage 3에서 provider화됨 → `localImageStorageServiceProvider` 사용으로 바꿔도 되나 **최소 변경 원칙상 이번 태스크는 auth 호출만 전환**하고 image/userId는 보류(보고에 명시)). gender/country 수집만·미전송 동작 보존.
3. View-local 상태(_selectedImage/_isSaving/_selectedGender 등) 유지.

- [ ] **Step 1:** profile_setup_screen 정독.
- [ ] **Step 2:** auth 호출만 전환.
- [ ] **Step 3:** `flutter analyze` clean. `grep AuthService.instance profile_setup_screen.dart` → 0. `flutter test` 통과.
- [ ] **Step 4: Commit** `|REFACTOR| profile_setup_screen — auth 호출 AuthRepository 경유(image/userId는 보류)`

---

## Task 8: profile_screen auth 부분 + pet_profile_screen + performLogout 승격

**Files:** Modify `lib/src/screens/profile/profile_screen.dart`(auth 부분), `lib/src/screens/pet/pet_profile_screen.dart`, `lib/src/providers/auth_actions.dart`(제거), `lib/src/view_models/pet/active_pet_view_model.dart`(주석).

**전환 규칙:**
1. **profile_screen**(Stage 3에서 pet/locale은 전환됨, auth만 남음): `_authService.getSocialAccounts`(L118)·`linkSocialAccount`(L142·171)·`unlinkSocialAccount`(L244)·`getProfile`(L311)·`deleteAccount`(L1329) → `ref.read(authRepositoryProvider)` 경유. `_authService` 필드 제거.
2. **performLogout 승격**: `await performLogout(ref)`(L1231) → `await ref.read(authViewModelProvider.notifier).logout()`. `auth_actions.dart`의 `performLogout` 자유함수 삭제. `active_pet_view_model.dart:31`의 주석(performLogout 계약 참조)을 `AuthViewModel.logout` 참조로 갱신.
3. **pet_profile_screen**: `_authService.getProfile()`(L35) → `ref.read(authRepositoryProvider).getProfile()`. `_authService` 필드(L24) 제거.
4. link/unlink는 소셜 SDK 자격이 필요할 수 있음 — 현재 profile_screen이 SDK 호출 후 idToken을 linkSocialAccount에 넘기는 구조면 그 SDK 호출은 View에 남기고 linkSocialAccount만 Repository 경유(Task 2 범위 밖). 실코드 확인 후 최소 변경.

- [ ] **Step 1:** profile_screen의 auth 부분(L42·118·142·171·244·311·1231·1329) + pet_profile_screen(L24·35) + auth_actions.dart + active_pet_view_model.dart:31 정독.
- [ ] **Step 2:** 적용. performLogout 삭제 후 콜러(profile L1231)가 VM.logout으로 바뀌었는지, 다른 콜러 없는지 grep 확인.
- [ ] **Step 3:** `flutter analyze lib/` clean. `grep -rn "AuthService.instance\|performLogout" lib/` → 0(전부 전환). `flutter test` 통과.
- [ ] **Step 4: Commit** `|REFACTOR| profile/pet_profile auth 전환 + performLogout→AuthViewModel.logout 승격`

---

## Self-Review (스펙 대비)

- **AuthRepository+AuthViewModel** (스펙 Stage 4 #1): Task 1-3 ✅
- **8화면 전환**: login/email_login(T4), signup(T5), forgot 3종(T6), profile_setup(T7), pet_profile 잔존(T8) ✅. profile_setup_complete는 서비스 호출 0으로 제외(정당).
- **hasPets 분기 일원화**(login:38·email_login:86): T3(destinationForHasPets)+T4 ✅
- **performLogout 승격**: T8 ✅
- **소셜 SDK를 Repository로**: T2+T4 ✅
- **profile_screen auth 마무리**: T8 ✅

**Placeholder scan:** Task 1의 credential 시그니처는 "idToken 직접 → Task 2에서 승격"으로 명시. resetPasswordByPhone은 "없으면 T6에서 추가" 명시.
**Type consistency:** LoginOutcome/LoginAuthenticated/LoginSignupRequired, PostLoginDestination, authRepositoryProvider/authViewModelProvider 일관.
**보류/후속(최종 보고):** signOut/deleteAccount FCM 비대칭(별도 결정), profile_setup image/userId 전환(보류), ErrorHandler 통일(forgot 화면), signInWithEmailPassword의 _lastHasPets stale 가능성(현재 무해).
