# 라우터 및 네비게이션 전체 검토/수정

**날짜**: 2026-01-29
**파일**:
- [lib/src/router/app_router.dart](../../lib/src/router/app_router.dart)
- [lib/src/router/route_names.dart](../../lib/src/router/route_names.dart)
- [lib/src/router/route_paths.dart](../../lib/src/router/route_paths.dart)
- [lib/src/widgets/bottom_nav_bar.dart](../../lib/src/widgets/bottom_nav_bar.dart)
- [lib/src/screens/wci/wci_index_screen.dart](../../lib/src/screens/wci/wci_index_screen.dart)
- [lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart](../../lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart)
- [lib/src/screens/pet/pet_profile_screen.dart](../../lib/src/screens/pet/pet_profile_screen.dart)
- [lib/src/screens/profile/pet_profile_detail_screen.dart](../../lib/src/screens/profile/pet_profile_detail_screen.dart)
- [lib/src/screens/profile/profile_screen.dart](../../lib/src/screens/profile/profile_screen.dart)
- [lib/src/screens/signup/signup_screen.dart](../../lib/src/screens/signup/signup_screen.dart)
- [lib/src/screens/weight/weight_record_screen.dart](../../lib/src/screens/weight/weight_record_screen.dart)

---

## 배경

라우터와 네비게이션에서 간헐적으로 효과가 안 되거나 동작하지 않는 경우가 발생하여, 전체 라우팅 시스템을 검토하고 발견된 문제들을 일괄 수정하였다.

---

## 발견된 문제 및 수정 내역

### 1. 인증 가드(redirect) 부재

**문제**: GoRouter에 `redirect` 함수가 없어서 비로그인 사용자가 `/home`, `/profile` 등 보호된 라우트에 직접 접근할 수 있었다. 스플래시 화면에서만 토큰 체크를 하고 있었으나, URL 직접 접근이나 딥링크를 통한 우회가 가능했다.

**수정**: `app_router.dart`에 `redirect` 함수 추가.

```dart
redirect: (context, state) {
  final isLoggedIn = TokenService.instance.isLoggedIn;
  final currentPath = state.uri.path;
  final isPublicRoute = _publicPaths.contains(currentPath);

  if (currentPath == RoutePaths.splash) return null;

  // 비로그인 → 보호 라우트 접근 시 로그인으로 리다이렉트
  if (!isLoggedIn && !isPublicRoute) return RoutePaths.login;

  // 로그인 사용자 → 인증 화면 접근 시 홈으로 리다이렉트
  if (isLoggedIn && (currentPath == RoutePaths.login || ...)) return RoutePaths.home;

  return null;
}
```

인증 없이 접근 가능한 공개 경로 목록:
- `/` (스플래시), `/onboarding`, `/login`, `/signup`, `/email-login`
- `/forgot-password/method`, `/forgot-password/code`, `/forgot-password/reset`

---

### 2. 날짜 파라미터 파싱 에러 핸들링

**문제**: `/weight/add/:date` 라우트에서 `DateTime.parse(dateStr)` 호출 시 잘못된 형식이 들어오면 `FormatException`으로 앱이 크래시되었다.

**수정**: try-catch로 감싸고 실패 시 `DateTime.now()` 폴백 적용.

```dart
// Before
final dateStr = state.pathParameters['date']!;
final date = DateTime.parse(dateStr);

// After
final dateStr = state.pathParameters['date'];
DateTime date;
try {
  date = DateTime.parse(dateStr ?? '');
} catch (_) {
  date = DateTime.now();
}
```

---

### 3. extra 파라미터 타입 안전성 강화

**문제**: 여러 라우트에서 `state.extra as Map<String, dynamic>?`로 캐스팅하고 있었는데, `extra`에 다른 타입이 전달되면 `TypeError` 런타임 에러가 발생했다.

**수정**: `as` 캐스팅 대신 `is` 타입 체크로 변경.

```dart
// Before
final extra = state.extra as Map<String, dynamic>?;

// After
final extra = state.extra;
final map = extra is Map<String, dynamic> ? extra : null;
```

적용된 라우트: `petAdd`, `forgotPasswordCode`, `forgotPasswordReset`, `profileSetupComplete`

---

### 4. 라우트명-화면 불일치 수정

**문제**: `weightDetail`이라는 라우트명이 `WeightRecordScreen`을 반환하고, `weightChart`가 `WeightDetailScreen`을 반환하여 이름과 화면이 뒤바뀌어 있었다.

**수정**:
- `weightDetail` → `WeightDetailScreen` (체중 상세/차트 화면)
- `weightChart` → `weightRecord`로 이름 변경, `WeightRecordScreen` (체중 기록 목록 화면)

변경된 상수:
| 변경 전 | 변경 후 |
|---------|---------|
| `RouteNames.weightChart` | `RouteNames.weightRecord` |
| `RoutePaths.weightChart` (`/weight/chart`) | `RoutePaths.weightRecord` (`/weight/record`) |

`bottom_nav_bar.dart`의 참조도 함께 업데이트.

---

### 5. 뒤로가기 처리 통일 (canPop 패턴)

**문제**: 일부 화면은 `context.pop()`만 호출하여, pop할 스택이 없을 때 아무 동작도 하지 않아 사용자가 화면에 갇힐 수 있었다. 반면 일부 화면은 `canPop` 체크 후 홈으로 폴백하는 안전한 패턴을 사용하고 있어 일관성이 없었다.

**수정**: 모든 뒤로가기 버튼에 통일된 패턴 적용.

```dart
if (context.canPop()) {
  context.pop();
} else {
  context.goNamed(RouteNames.home);
}
```

적용된 화면:
- `wci_index_screen.dart` — WCI 지수 화면 AppBar
- `ai_encyclopedia_screen.dart` — AI 백과사전 화면 AppBar
- `pet_profile_screen.dart` — 펫 프로필 화면 AppBar
- `pet_profile_detail_screen.dart` — 펫 프로필 상세 화면 AppBar + 저장 후 pop
- `profile_screen.dart` — 프로필 화면 뒤로가기 버튼

---

### 6. go() vs push() 혼용 수정

**문제**: `profile_screen.dart`의 뒤로가기 버튼에서 `context.goNamed(RouteNames.home)`을 사용하여, push로 진입했더라도 항상 스택을 초기화하고 홈으로 이동했다. `signup_screen.dart`에서 소셜 연동 시 `goNamed(profile)`을 사용하여 프로필에서 뒤로가기가 불가능했다.

**수정**:
- `profile_screen.dart`: `goNamed(home)` → `canPop` 패턴으로 변경하여 push로 진입한 경우 정상 pop 가능
- `signup_screen.dart`: `goNamed(profile)` → `goNamed(home)` + `pushNamed(profile)`로 변경하여 프로필에서 뒤로가기 시 홈으로 정상 이동

---

### 7. 회원가입 화면 이중 네비게이션 방지

**문제**: `login_screen.dart`과 `email_login_screen.dart`에는 `_hasNavigatedAfterLogin` 플래그가 있어 빠른 더블탭으로 인한 중복 네비게이션을 방지하고 있었으나, `signup_screen.dart`에는 해당 플래그가 없었다.

**수정**: `_hasNavigatedAfterSignup` 플래그를 추가하고, 소셜 연동 다이얼로그의 두 버튼(나중에 하기, 소셜 계정 연동하기) 모두에 적용.

```dart
bool _hasNavigatedAfterSignup = false;

// 각 버튼 핸들러
onPressed: () {
  if (_hasNavigatedAfterSignup) return;
  _hasNavigatedAfterSignup = true;
  Navigator.pop(dialogContext);
  context.goNamed(RouteNames.home);
},
```

---

### 8. 미사용 import 제거

`weight_record_screen.dart`에서 사용하지 않는 `spacing.dart` import를 제거.

---

## 검증

`flutter analyze` 실행 결과:
- **Error**: 0개
- **Warning**: 0개
- **Info**: 12개 (기존 코드의 스타일 권장사항, 라우터 수정과 무관)
