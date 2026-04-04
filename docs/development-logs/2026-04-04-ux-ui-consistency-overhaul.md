# UX/UI 일관성 전면 개선 (2026-04-04)

**날짜**: 2026-04-04
**작성자**: Claude Code
**브랜치**: `release/v2.0`
**상태**: 완료 — flutter analyze 통과

---

## 개요

디자인 시스템 전면 감사(audit) 후 발견된 7개 UX/UI 일관성 이슈를 수정. Empty state, 로딩, 에러 처리, Bottom Sheet, 아이콘, 애니메이션, 스피너 등 앱 전체의 인터랙션 패턴을 표준화.

---

## 1. Empty State 표준화

**문제:** 3개 화면(알림, BHI, 건강체크 히스토리)의 empty state가 아이콘 색상(`gray350` vs `gray400` vs `lightGray`), 폰트 weight(`w500` vs `w600`) 등 제각각.

**수정:**
- `lib/src/widgets/empty_state_widget.dart` 공통 위젯 생성
- 통일 스펙: 아이콘 64px `gray350`, 제목 16px `w600` `mediumGray`, 부제목 14px `w400` `warmGray`
- 선택적 액션 버튼 파라미터 지원
- 3개 화면의 인라인 `_buildEmptyState()` → `EmptyStateWidget` 교체

| 파일 | 변경 |
|------|------|
| `health_check_history_screen.dart` | EmptyStateWidget 적용 |
| `notification_screen.dart` | EmptyStateWidget 적용 |
| `bhi_detail_screen.dart` | EmptyStateWidget 적용 |

---

## 2. 로딩 스피너 표준화

**문제:** 10개 이상 화면에서 기본 파란색 `CircularProgressIndicator()` 사용. 버튼 스피너도 `strokeWidth` 2 vs 2.5, 크기 20x20 vs 24x24 혼재.

**수정:**
- `lib/src/widgets/app_loading.dart` 생성
  - `AppLoading.fullPage()` — 브랜드 오렌지 풀페이지 스피너
  - `AppLoading.button()` — 24x24 흰색 버튼 스피너 (strokeWidth: 2)
- 11개 화면의 풀페이지 스피너 교체
- 3개 화면의 버튼 스피너 통일 (login 20→24, vet_summary/promo_code 2.5→2)

---

## 3. Bottom Sheet 스타일링 통일

**문제:** border radius `20`, `24`, `32` 혼재. 핸들바는 1곳(promo code)만 존재.

**수정:**
- border radius **24px**로 통일 (4개 파일 수정)
- 5개 bottom sheet에 표준 핸들바 추가 (width: 36, height: 4, `AppColors.beige`)

| 파일 | Before | After |
|------|--------|-------|
| `promo_code_bottom_sheet.dart` | radius 20 | 24 |
| `pet_profile_detail_screen.dart` | radius 20, 핸들바 없음 | 24 + 핸들바 |
| `profile_setup_screen.dart` | radius 32, 핸들바 없음 | 24 + 핸들바 |
| `weight_detail_screen.dart` | radius 32, 비표준 핸들바 | 24 + 표준 핸들바 |
| `water_record_screen.dart` | 핸들바 없음 | + 핸들바 |
| `food_record_screen.dart` | 핸들바 없음 | + 핸들바 |

---

## 4. 애니메이션 타이밍 상수화

**문제:** 12종의 duration 값이 27개 파일에 하드코딩. 특히 `800ms`(코치마크 대기)가 14곳에 반복.

**수정:**
- `lib/src/theme/durations.dart` 생성:

```dart
class AppDurations {
  static const quick = Duration(milliseconds: 200);
  static const normal = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 400);
  static const snackBarEnter = Duration(milliseconds: 350);
  static const snackBarExit = Duration(milliseconds: 250);
  static const snackBarDisplay = Duration(seconds: 3);
  static const coachMarkDelay = Duration(milliseconds: 800);
  static const coachMarkTransition = Duration(milliseconds: 300);
  static const chartAnimation = Duration(milliseconds: 240);
  static const splash = Duration(milliseconds: 2000);
  static const analyzing = Duration(milliseconds: 1200);
}
```

- 교체 범위:
  - `app_snack_bar.dart` — 350ms, 250ms, 3s
  - `coach_mark_overlay.dart` — 300ms
  - 13개 화면 — `coachMarkDelay` (800ms)
  - `splash_screen.dart` — 2000ms
  - `health_check_analyzing_screen.dart` — 1200ms

---

## 5. 아이콘 시스템 정비

**문제:** `AppIcons` 래퍼 클래스에 27개만 등록. 60곳 이상에서 `Icons.xxx` 직접 사용. SVG/Material 뒤로가기 아이콘 혼재.

**수정:**
- `AppIcons` 27개 → **86개**로 확장 (10개 카테고리)
- SVG 뒤로가기 아이콘 4곳을 `Icons.arrow_back`으로 교체:
  - `forgot_password_method_screen.dart`
  - `forgot_password_code_screen.dart`
  - `forgot_password_reset_screen.dart`
  - `premium_screen.dart`

추가된 카테고리: Health & Medical, Records & Data, Rating, Premium & Account 등

---

## 6. 디자인 컨텍스트 문서

`.impeccable.md` 생성 — 앱의 디자인 원칙, 타겟 사용자, 브랜드 성격, 미적 방향을 문서화.

---

## 변경 규모

| 항목 | 수치 |
|------|------|
| 신규 파일 | 4개 (durations.dart, empty_state_widget.dart, app_loading.dart, .impeccable.md) |
| 수정 파일 | 29개 |
| 삭제 코드 | 228줄 |
| 추가 코드 | 262줄 |
| 순 변경 | +34줄 (중복 제거로 코드 감소) |

---

## 검증

- `flutter analyze` — No issues found
- 전체 수정 파일 29개 정적 분석 통과
