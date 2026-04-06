# 로그인/UX 수정

> 구현일: 2026-03-28

## 1. 로그인 버튼 디자인 통일 + Google 브랜딩 준수

### 배경
- Google 브랜딩 가이드라인 미준수 (테두리/텍스트 색상, 폰트, 문구)
- Google / Apple / 이메일 로그인 버튼이 각각 다른 스타일 (높이, border radius, 레이아웃 불일치)
- Apple은 `SignInWithAppleButton` 패키지 위젯, 이메일은 그라데이션 버튼, Google은 커스텀 — 통일감 없음

### 해결
3개 버튼을 공통 `_buildSocialLoginButton()` 메서드로 통일:

| 버튼 | 배경 | 테두리 | 아이콘 | 텍스트 |
|------|------|--------|--------|--------|
| Google | 흰색 | `#747775` | Google 'G' 로고 (20px) | "Google로 로그인" |
| Apple | 검정 | 검정 | Apple 로고 흰색 (20px) | "Apple로 로그인" |
| 이메일 | 흰색 | 브랜드 오렌지 | mail 아이콘 오렌지 (20px) | "이메일로 로그인" |

공통 사양: 높이 56px, borderRadius 16, 아이콘+텍스트 중앙 정렬, 간격 10px, 폰트 15px w600

### Apple 로고 변경
- Before: `apple_logo_black.svg` (56x56, 흰색 배경 사각형 포함 — 축소 시 부자연스러움)
- After: `btn_apple.svg` (20x20, 순수 경로만) + `ColorFilter`로 흰색 변환

### Google 브랜딩 가이드라인 준수 항목
- 테두리: `#97928A` → `#747775`
- 텍스트: `Colors.black` → `#1F1F1F`
- 문구: "구글로 로그인" → "Google로 로그인" / "Login with Google" → "Sign in with Google"

### 수정 파일
- `lib/src/screens/login/login_screen.dart` — `SignInWithAppleButton` 패키지 제거, `_buildSocialLoginButton()` 통일
- `lib/src/screens/login/email_login_screen.dart` — Google 아이콘 버튼 border color `#747775`
- `lib/l10n/app_ko.arb`, `app_en.arb`, `app_zh.arb` — `login_email`, `login_apple` 문구 추가/수정
- `pubspec.yaml` — `google_fonts` 패키지 추가

## 1-1. 소셜 계정 연동 버튼 디자인 개선

프로필 화면의 소셜 계정 연동 행(row) 디자인 개선.

### Before
- Apple 로고: `apple_logo_black.svg` (56x56 + 흰색 배경 포함) → 24px 렌더링 시 부자연스러움
- 단순 border + 텍스트 + 작은 연동/해제 버튼

### After
- 아이콘: 36x36 흰색 라운드 박스 안에 20x20 아이콘 (Google 'G', Apple 로고)
- Apple 로고: `btn_apple.svg` (깔끔한 경로만)
- 상태 서브텍스트: "연동됨" (브랜드 컬러) / "미연동" (회색)
- 연동/해제 버튼: pill 형태 (borderRadius 20)
- 카드 배경: 연동 시 `brandPale`, 미연동 시 `gray50`
- 높이 56 → 60, 간격 8 → 10

### 수정 파일
- `lib/src/screens/profile/profile_screen.dart` — `_buildSocialAccountRow()` 리디자인
- `lib/l10n/app_ko.arb`, `app_en.arb`, `app_zh.arb` — `profile_linked`, `profile_notLinked` 추가

---

## 2. Kakao OAuth 완전 제거

카카오 로그인은 사용하지 않으므로 관련 코드/설정/에셋 전체 제거.

### 제거 항목
- `ios/Runner/Info.plist` — Kakao URL scheme + LSApplicationQueriesSchemes
- `android/app/src/main/AndroidManifest.xml` — `AuthCodeHandlerActivity` + intent filter
- `lib/src/services/auth/auth_service.dart` — `signInWithKakao()` 메서드
- `lib/src/screens/profile/profile_screen.dart` — Kakao 연동 주석 블록 + switch case
- `lib/l10n/app_ko.arb`, `app_en.arb`, `app_zh.arb` — 8개 Kakao 관련 키 제거
- `assets/images/btn_kakao/` — 폴더 삭제

### 잔존 항목 (백엔드)
- `backend/app/routers/auth.py` — `/auth/oauth/kakao` 엔드포인트
- `backend/app/utils/security.py` — `verify_kakao_access_token()`
- 프론트에서 호출하지 않으므로 당장 문제 없음. 백엔드 정리 시 함께 제거 권장.

---

## 3. 코치마크 타이밍 버그 수정

### 문제
- `profileSetup`은 `/home/profile/setup` 경로 — Home의 자식 라우트
- `StatefulShellRoute.indexedStack`이므로 profileSetup 이동 시에도 HomeScreen이 빌드됨
- `initState()` → `_loadPets()` → `_maybeShowCoachMarks()` 호출
- 800ms 후 코치마크 오버레이가 profileSetup 위에 회색 반투명으로 표시됨
- 이후 홈 복귀 시 `initState`는 이미 완료되어 코치마크가 재트리거되지 않음

### 해결
`lib/src/screens/home/home_screen.dart`:

1. `_maybeShowCoachMarks()`에서 `GoRouterState.of(context).uri.path` 확인 — 홈이 아니면 `_pendingCoachMark = true` 설정 후 return
2. `didChangeDependencies()`에서 `_pendingCoachMark && !_isLoading` 조건 시 `_loadPets()` 재호출 → 코치마크 재트리거

---

## 4. 키보드 dismiss 전역 적용

### 문제
프로필 설정 등 TextField가 있는 화면에서 빈 영역 탭 시 키보드가 닫히지 않음.

### 해결
`GestureDetector(onTap: () => FocusScope.of(context).unfocus(), behavior: HitTestBehavior.opaque)` 패턴을 누락된 7개 화면에 적용.

### 적용 파일
- `lib/src/screens/profile_setup/profile_setup_screen.dart`
- `lib/src/screens/pet/pet_add_screen.dart`
- `lib/src/screens/login/email_login_screen.dart`
- `lib/src/screens/forgot_password/forgot_password_method_screen.dart`
- `lib/src/screens/forgot_password/forgot_password_code_screen.dart`
- `lib/src/screens/forgot_password/forgot_password_reset_screen.dart`
- `lib/src/screens/profile/pet_profile_detail_screen.dart`

---

## 5. 회원탈퇴 이중 확인 + 안내문 개선

### 변경 사항
`lib/src/screens/profile/profile_screen.dart` — `_handleDeleteAccount()`:

**1단계 다이얼로그** (데이터 삭제 안내):
- 기존: "모든 데이터가 삭제되며 복구할 수 없습니다."
- 변경: "체중, 사료, 수분, 건강체크 등 기록된 모든 데이터가 영구적으로 삭제되며 복구할 수 없습니다."

**2단계 다이얼로그** (최종 확인):
- 제목: "정말 탈퇴하시겠습니까?" / "Are you sure?" / "确定要注销吗？"
- 내용: "이 작업은 되돌릴 수 없습니다."

### 로컬라이제이션 추가 키
- `dialog_deleteAccountFinalTitle` (KO/EN/ZH)
- `dialog_deleteAccountFinalContent` (KO/EN/ZH)
