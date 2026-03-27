# v2.0 코드 리뷰 수정 사항

> 날짜: 2026-03-28
> 대상 브랜치: `release/v2.0`
> 범위: 실기기 테스트 체크리스트 기반 전체 코드 리뷰 + 에러 핸들링 전수 검사

---

## 1차: 기능 코드 리뷰 (6건)

### CRITICAL-1. 펫 전환 시 건강 데이터 갱신 실패

**파일:** `lib/src/screens/home/home_screen.dart`

**문제:** `build()` 메서드에서 Riverpod provider 변경을 감지하고 `_refreshForPet()`을 `addPostFrameCallback`으로 예약하지만, 바로 다음 줄에서 `_activePet = activePet`을 동기적으로 업데이트. `_refreshForPet` 내부 가드(`if (_activePet?.id == petId) return`)가 이미 업데이트된 값을 보고 early return하여 BHI/WCI/건강 데이터 로드를 스킵.

**증상:** 프로필 화면에서 펫 전환 후 홈 복귀 시, 펫 이름은 바뀌지만 건강 점수·체중·사료·수분 상태는 이전 펫 데이터 그대로 표시.

**수정:** `_refreshForPet`에서 중복 방지 가드 제거. `_bhiRequestId` 카운터가 이미 race condition을 방지하므로 안전.

```dart
// Before
Future<void> _refreshForPet(String petId) async {
  if (_activePet?.id == petId) return; // ← 항상 true여서 스킵됨
  ...
}

// After
Future<void> _refreshForPet(String petId) async {
  // 가드 제거 — _bhiRequestId로 race condition 보호
  ...
}
```

---

### HIGH-1. 이메일 로그인 `_navigateAfterLogin()` await 누락

**파일:** `lib/src/screens/login/email_login_screen.dart:564`

**문제:** `_handleLogin()`에서 `_navigateAfterLogin()` 호출 시 `await` 없음. `finally` 블록이 즉시 실행되어 `_isLoading = false` → 네비게이션 완료 전 로그인 버튼 재활성화.

**수정:** `await _navigateAfterLogin();`

---

### HIGH-2. 비밀번호 재설정 Timer mounted 미확인

**파일:** `lib/src/screens/forgot_password/forgot_password_code_screen.dart:72-80`

**문제:** `Timer.periodic` 콜백에서 `setState()` 호출 시 `mounted` 체크 없음. 사용자가 타이머 작동 중 화면을 떠나면 `setState() called after dispose()` 에러 발생.

**수정:**
```dart
_timer = Timer.periodic(const Duration(seconds: 1), (timer) {
  if (!mounted) { timer.cancel(); return; }  // ← 추가
  if (_remainingSeconds > 0) {
    setState(() => _remainingSeconds--);
  } else {
    timer.cancel();
  }
});
```

---

### HIGH-3. 소셜 로그인 에러 메시지 불일치

**파일:** `lib/src/screens/login/email_login_screen.dart:101-103`

**문제:** `_handleSocialLoginResult`에서 `signupRequired` 시 `error_loginRetry` (범용 메시지) 사용. 동일 로직인 `login_screen.dart:53`에서는 `error_socialAccountConflict` (정확한 메시지) 사용.

**수정:** `l10n.error_loginRetry` → `l10n.error_socialAccountConflict`

---

### MEDIUM-1. 미사용 `btn_naver/` 에셋 제거

**파일:** `pubspec.yaml:66` + `assets/images/btn_naver/`

**문제:** Naver OAuth 미구현인데 에셋 디렉토리와 pubspec 참조가 남아 있어 번들 크기 낭비.

**수정:** pubspec.yaml에서 `assets/images/btn_naver/` 줄 제거 + 디렉토리 삭제.

---

### MEDIUM-2. 개인정보처리방침 Kakao 잔존 텍스트

**파일:** `lib/src/data/terms_content.dart` (6곳)

**문제:** Kakao OAuth 코드 전체 제거했으나 개인정보처리방침 텍스트에 "Kakao Login" 언급 잔존 (KO 2곳, EN 2곳, ZH 2곳).

**수정:** 3개 언어 모두에서 Kakao 관련 텍스트 삭제.
- 소셜 로그인 수집 항목에서 Kakao 행 제거
- 외부 서비스 목록에서 "Kakao Login" 제거

---

## 2차: 에러 핸들링 전수 검사 (6건)

### ERR-1. 건강체크 분석 — 서버 raw 에러 메시지 사용자 노출

**파일:** `lib/src/screens/health_check/health_check_analyzing_screen.dart:178`

**문제:** `ApiException` catch에서 403 외 모든 에러에 `e.message` (서버 원문) 직접 표시. 500 에러 시 내부 서버 메시지, 비영어권 사용자에게 영어 에러 텍스트 노출 가능.

**수정:**
```dart
// Before
_errorMessage = e.statusCode == 403
    ? l10n.premium_healthCheckBlocked
    : e.message;  // ← 서버 raw 메시지

// After
_errorMessage = e.statusCode == 403
    ? l10n.premium_healthCheckBlocked
    : (e.statusCode >= 500 ? l10n.error_server : l10n.hc_analysisError);
```

---

### ERR-2. 건강체크 이미지 선택 — `e.toString()` 사용자 노출

**파일:** `lib/src/screens/health_check/health_check_capture_screen.dart:93`

**문제:** 이미지 선택 실패 시 `hc_imagePickError(e.toString())` — "PlatformException(already_active, ...)" 같은 기술적 예외 문자열이 사용자에게 표시됨.

**수정:** `e.toString()` → `l10n.error_unexpected` + `ScaffoldMessenger` → `AppSnackBar.error` 통일.

---

### ERR-3. 건강체크 분석 — 프리미엄 체크 실패 후 mounted 미확인

**파일:** `lib/src/screens/health_check/health_check_analyzing_screen.dart:74`

**문제:** `_checkPremiumThenAnalyze()`에서 `catch (_) {}` 후 바로 `_startAnalysis()` 호출. 위젯이 이미 dispose된 경우에도 진행.

**수정:** `if (!mounted) return;` 가드 추가.

---

### ERR-4. 건강체크 메인 — 네트워크 에러 시 설명 없이 잠금

**파일:** `lib/src/screens/health_check/health_check_main_screen.dart:75`

**문제:** 프리미엄 상태 확인 API 실패 시 `_isLocked = true` 설정하지만 에러 메시지 없음. 사용자는 프리미엄이 아니어서 잠긴 건지, 네트워크 문제인지 구분 불가.

**수정:** `SocketException`/`TimeoutException` 감지 시 `error_network` 스낵바 표시. import에 `dart:async`, `dart:io`, `app_snack_bar.dart` 추가.

---

### ERR-5. ErrorHandler — 로그인/회원가입 429 Rate Limit 미처리

**파일:** `lib/src/utils/error_handler.dart`

**문제:** `_getLoginError`, `_getSignupError`, `_getGeneralApiError`에 429 케이스 없음. 체크리스트의 "로그인 10회 초과 → 429", "회원가입 5회 초과 → 429" 시나리오에서 범용 에러 메시지(`error_loginRetry` / `error_unexpected`) 표시.

**수정:** 3개 메서드 모두에 `case 429: return l10n.error_tooManyRequests;` 추가.

```dart
// _getLoginError, _getSignupError, _getGeneralApiError 각각에 추가:
case 429:
  return l10n.error_tooManyRequests;
```

---

### ERR-6. 알림 화면 — 로드 실패 사일런트

**파일:** `lib/src/screens/notification/notification_screen.dart:49`

**문제:** 알림 목록 로드 실패 시 `setState(() => _isLoading = false)` 만 실행. 빈 화면 표시되지만 에러인지 알림이 없는 건지 사용자가 구분 불가.

**수정:** `error_network` 스낵바 표시 추가.

---

## 수정하지 않은 항목 (의도적 설계 확인)

| 항목 | 파일 | 판단 근거 |
|------|------|----------|
| food/water 로드 실패 사일런트 | food_record_screen, water_record_screen | SharedPreferences 폴백으로 로컬 데이터 표시됨 |
| weight_detail 다중 사일런트 catch | weight_detail_screen | 4단계 폴백 구조 (서버→캐시→로컬→빈값) |
| profile 소셜/프리미엄 로드 사일런트 | profile_screen | 보조 정보, 화면 진입에 영향 없음 |
| food/water 서버 저장 실패 | food_record_screen, water_record_screen | SyncService.enqueue() + snackbar_savedOffline 표시 |
| GoogleSignInException catch 순서 | login_screen | Dart 정상 패턴 (구체적→일반적) |
| 회원탈퇴 이중 확인 mounted 체크 | profile_screen | 양쪽 다이얼로그 모두 `!mounted` 체크 확인됨 |
| 코치마크 didChangeDependencies | home_screen | `_pendingCoachMark` 가드 정상 동작 |
| 다국어 키 동기화 (769키) | app_*.arb | EN/KO/ZH 완전 일치 확인 |
| Google 브랜딩 (색상·문구) | login_screen, email_login_screen | #747775 테두리, #1F1F1F 텍스트 준수 |
| Kakao 코드 완전 제거 | auth, UI, l10n 전체 | 코드·설정·에셋 모두 제거 확인 |
| iOS/Android 딥링크 | Info.plist, AndroidManifest | perchcare://auth-callback 보존 확인 |

---

## v2.1 개선 권장 사항

| 항목 | 설명 |
|------|------|
| 토큰 만료 자동 로그아웃 | `_refreshToken()` 실패 시 토큰 삭제만 하고 UI 알림 없음. 앱 레벨 로그아웃 이벤트 스트림 필요 |
| ErrorContext 확장 | healthCheck/foodSave/waterSave 컨텍스트 추가하여 에러 메시지 세분화 |
| DailyRecordService 에러 핸들링 | 모든 메서드가 try-catch 없이 API 직접 호출 — 에러 시 크래시 가능 |

---

## 수정 파일 목록

| 파일 | 수정 사유 |
|------|----------|
| `lib/src/screens/home/home_screen.dart` | CRITICAL-1 |
| `lib/src/screens/login/email_login_screen.dart` | HIGH-1, HIGH-3 |
| `lib/src/screens/forgot_password/forgot_password_code_screen.dart` | HIGH-2 |
| `lib/src/data/terms_content.dart` | MEDIUM-2 |
| `pubspec.yaml` | MEDIUM-1 |
| `lib/src/screens/health_check/health_check_analyzing_screen.dart` | ERR-1, ERR-3 |
| `lib/src/screens/health_check/health_check_capture_screen.dart` | ERR-2 |
| `lib/src/screens/health_check/health_check_main_screen.dart` | ERR-4 |
| `lib/src/utils/error_handler.dart` | ERR-5 |
| `lib/src/screens/notification/notification_screen.dart` | ERR-6 |
