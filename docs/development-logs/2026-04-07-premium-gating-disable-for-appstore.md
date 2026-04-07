# 프리미엄 게이팅 임시 비활성화 — App Store 3.1.1 리젝 대응

**날짜**: 2026-04-07
**관련 이슈**: App Store Guideline 3.1.1 (In-App Purchase) 위반 리젝
**Submission ID**: 875ed59f-faa4-45a5-a66b-0570c6856211
**전략**: 방안 C — 프리미엄 게이팅 자체를 임시 제거하여 모든 기능 무료 개방

---

## 배경

App Store 리뷰에서 2건 지적:
1. 자체 프로모 코드(`PERCH-XXXX-XXXX`)로 프리미엄 해제 — IAP 외 결제 수단 금지
2. 프리미엄 기능 존재하나 IAP 구매 경로 없음 — 유료 콘텐츠는 반드시 IAP로 구매 가능해야 함

IAP 활성화에 필요한 유료 앱 계약(Paid Applications Agreement) 준비 전이므로, 프리미엄 게이팅을 임시 비활성화하는 방안 선택.

## 핵심 아이디어

`AppConfig.premiumEnabled = false` 플래그 1개 + `PremiumStatus` getter 오버라이드로 앱 전체가 프리미엄 상태로 동작하게 만든다. 대부분의 화면이 이미 `isPremium`/`isFree` 분기를 사용하므로 개별 수정 최소화.

---

## 변경 파일 (7개)

### 1. `lib/src/config/app_config.dart`
- `static const bool premiumEnabled = false` 추가
- 이 플래그 하나로 전체 프리미엄 시스템 on/off 제어

### 2. `lib/src/services/premium/premium_service.dart`
- `import '../../config/app_config.dart'` 추가
- `PremiumStatus.isPremium` → `!AppConfig.premiumEnabled || tier == 'premium'` (항상 true)
- `PremiumStatus.isFree` → `AppConfig.premiumEnabled && tier != 'premium'` (항상 false)
- `EncyclopediaQuota.isUnlimited` → `!AppConfig.premiumEnabled || monthlyLimit == -1` (항상 unlimited)
- `VisionQuota.isUnlimited` → `!AppConfig.premiumEnabled || monthlyLimit == -1` (항상 unlimited)

이 변경으로 **자동 해결되는 위치** (별도 수정 불필요):
| 화면 | 효과 |
|------|------|
| health_check_capture_screen | hasAccess 항상 true |
| health_check_main_screen | _isLocked = false, 기능 잠금 해제 |
| home_screen | _isPremium = true, 인사이트 표시, 잠금 카드 미렌더링 |
| ai_encyclopedia_screen | 프리미엄 배너 미표시, 쿼터 뱃지 미표시 |
| profile_screen | "Premium" 뱃지 표시, "Enter Code" 미표시 |
| health_check_history_screen:197 | isFree 가드 통과 |
| vet_summary_screen:38 | isFree 가드 통과 |

### 3. `lib/src/screens/health_check/health_check_analyzing_screen.dart`
- `import '../../config/app_config.dart'` 추가
- `_isPremiumError = e.statusCode == 403` → `AppConfig.premiumEnabled && e.statusCode == 403`
- 효과: 서버 403 시 프리미엄 에러 UI + 업그레이드 버튼 미표시

### 4. `lib/src/screens/health_check/health_check_history_screen.dart`
- `import '../../config/app_config.dart'` 추가
- 403 catch에서 `if (e.statusCode == 403)` → `if (AppConfig.premiumEnabled && e.statusCode == 403)`
- 효과: 403 시 페이월 리다이렉트 대신 일반 에러 스낵바 표시

### 5. `lib/src/screens/health_check/vet_summary_screen.dart`
- `import '../../config/app_config.dart'` 추가
- 동일하게 403 페이월 리다이렉트를 `AppConfig.premiumEnabled` 가드로 감쌈

### 6. `lib/src/screens/premium/premium_screen.dart`
- `import '../../config/app_config.dart'` 추가
- `initState()`에서 `!AppConfig.premiumEnabled`이면 `context.pop()`으로 즉시 복귀
- `_maybeShowCoachMarks()`에서 `!AppConfig.premiumEnabled`이면 early return
- 효과: 딥링크 등으로 직접 진입해도 바로 뒤로 이동, 프로모 코드 코치마크 미표시

### 7. `lib/src/screens/profile/profile_screen.dart`
- `import '../../config/app_config.dart'` 추가
- 코치마크 steps 목록에서 프리미엄 카드 스텝을 `if (AppConfig.premiumEnabled)` 가드로 감쌈
- 효과: "프리미엄 카드를 눌러보세요" 코치마크 미표시

---

## 변경하지 않은 것

| 항목 | 이유 |
|------|------|
| `app_router.dart` 라우트 정의 | 유지 — 화면이 자동 pop됨 |
| `promo_code_bottom_sheet.dart` | 파일 유지 — 호출 경로가 차단됨 |
| `iap_service.dart` | 이미 비활성화 상태, 그대로 유지 |
| `quota_badge.dart` 위젯 | 렌더링 안 됨 (isUnlimited = true) |
| 로컬라이제이션 문자열 | 그대로 유지 |
| 백엔드 API | 변경 없음 |

---

## 복원 방법

IAP 준비 완료 시 한 줄만 변경:

```dart
// lib/src/config/app_config.dart
static const bool premiumEnabled = true;
```

모든 프리미엄 게이팅, 코치마크, 페이월 내비게이션, 쿼터 뱃지, 프로모 코드 흐름이 즉시 복원됨.

---

## 검증 결과

- `flutter analyze`: 새 에러/경고 없음 (기존 unused_element 3개만 존재 — 주석 처리된 IAP UI 메서드)

## 수동 테스트 체크리스트

- [ ] AI 건강체크: 쿼터 제한 없이 사용 가능
- [ ] AI 백과사전: 프리미엄 배너/쿼터 뱃지 미표시
- [ ] 건강체크 기록: 접근 차단 없이 열림
- [ ] 수의사 요약: 접근 차단 없이 열림
- [ ] 프로필: "Premium" 뱃지 표시, "Enter Code" 미표시
- [ ] 홈: 잠금 인사이트 카드 없음
- [ ] 프리미엄 화면 직접 진입 시 자동 pop
