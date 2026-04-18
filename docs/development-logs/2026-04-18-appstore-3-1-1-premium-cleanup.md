# App Store 3.1.1 리젝 2차 대응 — 프리미엄 흔적 제거 + 월간 한도 UX 전환

**날짜**: 2026-04-18
**관련 이슈**: App Store Guideline 3.1.1 (In-App Purchase) 재리젝 방지
**Submission ID**: 875ed59f-faa4-45a5-a66b-0570c6856211 (이전 리뷰)
**선행 커밋**: `f23c762 |FIX| App Store 3.1.1 리젝 대응 — premiumEnabled 플래그로 프리미엄 게이팅 임시 비활성화`
**전략**: 플래그 가드(1차) → 코드 레벨 제거 + Freemium → Monthly Quota UX 전환 (2차)

---

## 배경

`f23c762` 1차 대응은 `AppConfig.premiumEnabled = false` 단일 플래그로 `PremiumStatus.isFree`가 항상 `false`를 반환하도록 만들어 프리미엄 게이팅을 무력화했다. 이 방식은 **최소 변경으로 동작**하지만 다음 한계가 있다:

1. **코드 상 IAP/프로모 흔적 잔존** — 페이월 내비게이션(`pushNamed(RouteNames.premium)`), 업그레이드 CTA 위젯(`_buildFreeTrialBanner`, `_buildLockedOverlay`), 업그레이드 문구(`premium_healthCheckBlocked = "프리미엄 전용 기능"`)가 그대로 남아 있어 리뷰어가 정적 분석 또는 동적 deep-link로 찾아낼 가능성 존재.
2. **런타임 분기에 플래그가 광범위 침투** — 7개 파일에 `AppConfig.premiumEnabled` 조건이 흩어져 있어 추후 IAP 복원 시점에 역분석 비용 증가.
3. **UX 메시지 불일치** — 서버 403 응답 시 표시되는 "프리미엄 전용 기능" 문구가 "업그레이드 유도"로 해석될 수 있음. Apple이 요구하는 것은 "유료 디지털 콘텐츠가 존재하면 반드시 IAP로 구매 가능" 조건인데, 이 문구 자체가 유료 계약이 있어야 해소 가능한 장벽처럼 읽힌다.

2차 대응의 목표: 앱의 표면을 **"freemium + upgrade paywall"이 아닌 "월간 사용 한도(monthly quota)를 가진 표준 rate-limit 앱"**으로 보이게 만든다. 재리뷰 제출 시 3.1.1 재지적 리스크를 구조적으로 제거하고, 유료 계약 체결 후 IAP 복원 경로는 `premium_screen.dart`의 설계(주석 + `ignore_for_file: unused_element`)와 `iap_service.dart` 파일 존재로 남겨둔다.

---

## 핵심 아이디어

| 영역 | 1차 대응 (flag guard) | 2차 대응 (code removal + UX shift) |
|------|----------------------|------------------------------------|
| 프리미엄 상태 계산 | `!AppConfig.premiumEnabled \|\| tier == 'premium'` | `tier == 'premium'` (서버 응답이 정답 소스) |
| 403 에러 UX | "프리미엄 전용 기능" + 업그레이드 버튼 | "월간 한도 도달" + 재시도 버튼 숨김 |
| 업그레이드 CTA | 플래그로 숨김 | 위젯/콜백 파라미터 자체를 제거 |
| Free 유저 UI | 잠금 오버레이 + 티저 카드 렌더링 (플래그로 비활성) | 해당 블록을 코드에서 삭제, 프리미엄 상세는 섹션 비노출 |
| 3개 언어 문자열 | "프리미엄 전용입니다" | "이번 달 사용 한도에 도달했어요 / 다음 달에 다시" |
| IAP 복원 경로 | 플래그 한 줄 변경 | 본 커밋의 revert + 플래그 true 전환 |

---

## 변경 파일 (18개)

### 카테고리 A — Freemium UX → Monthly Quota UX 전환 (8 파일)

| 파일 | 변경 |
|------|------|
| `lib/l10n/app_ko.arb` | `premium_healthCheckBlocked` → "이번 달 사용 한도에 도달했어요.\n다음 달에 다시 이용해 주세요." · `premium_healthCheckBlockedTitle` → "월간 한도 도달" |
| `lib/l10n/app_en.arb` | 대응 영문: "You've reached this month's usage limit." / "Monthly Limit Reached" |
| `lib/l10n/app_zh.arb` | 대응 중문: "您已达到本月的使用上限。" / "本月限额已达" |
| `lib/l10n/app_localizations.dart` + `app_localizations_{ko,en,zh}.dart` | arb 변경에 맞춘 자동 생성 파일 |
| `lib/src/screens/health_check/health_check_analyzing_screen.dart` | `_isPremiumError` → `_isQuotaExhausted` 리네임. 403 시 `Icons.workspace_premium` → `Icons.hourglass_bottom`, 색상 `brandPrimary` → `warmGray`. 업그레이드 CTA 블록 + `_openPremiumPaywallAndRetry()` 헬퍼 제거. 쿼터 소진 시 재시도 버튼 숨김(재시도해도 실패하므로) — "뒤로" 버튼만 남김 |

### 카테고리 B — 업그레이드 CTA / Paywall 진입 경로 제거 (6 파일)

| 파일 | 변경 |
|------|------|
| `lib/src/widgets/quota_badge.dart` | `QuotaBadge` / `VisionQuotaBadge`에서 `upgradeText`, `onUpgradePressed` 파라미터 제거. exhausted 상태의 업그레이드 버튼 서브위젯(~30 LOC × 2) 전체 삭제. doc comment도 "월간 한도 도달" 톤으로 갱신 |
| `lib/src/widgets/health_summary_card.dart` | `onUpgradePressed` 파라미터 + `_buildLockedOverlay()` (블러 + 자물쇠 CTA, ~65 LOC) 삭제. Free 유저에게는 이상 소견 / 급여·음수 일관성 / BHI 추세 섹션 **자체를 비노출**. `import 'dart:ui'` 제거 |
| `lib/src/screens/home/home_screen.dart` | `_buildInsightsSection` Free 사용자용 "인사이트 업그레이드" 티저 카드 블록(~50 LOC) 삭제. `HealthSummaryCard`에 `onUpgradePressed` 콜백 인자 제거 |
| `lib/src/screens/health_check/health_check_main_screen.dart` | `VisionQuotaBadge`에서 `upgradeText`/`onUpgradePressed` 인자 제거. `_openPremiumPaywall()` 메서드는 IAP 복원 시 재사용 위해 남기고 `// ignore: unused_element` 주석 추가 |
| `lib/src/screens/health_check/health_check_history_screen.dart` | 공유 403 시 `context.pushNamed(RouteNames.premium)` → `ScaffoldMessenger.showSnackBar(SnackBar(content: Text(l10n.report_shareFailed)))`. `AppConfig.premiumEnabled` 가드 삭제(불필요) |
| `lib/src/screens/health_check/vet_summary_screen.dart` | 동일 패턴. `AppConfig`, `RouteNames` import 제거 |

### 카테고리 C — Premium 서비스/화면 단순화 (4 파일)

| 파일 | 변경 |
|------|------|
| `lib/src/services/premium/premium_service.dart` | `EncyclopediaQuota.isUnlimited` / `VisionQuota.isUnlimited` / `PremiumStatus.isPremium` / `.isFree` 게터에서 `AppConfig.premiumEnabled` 분기 제거 → 순수 `tier == 'premium'` / `monthlyLimit == -1` 기반으로 회귀. `import '../../config/app_config.dart'` 제거 |
| `lib/src/screens/premium/premium_screen.dart` | 파일 최상단에 2차 대응 의도 설명 주석 + `// ignore_for_file: unused_element` 추가. 미사용 `SnsEventCard` import 제거. `if (!_isPremium)` 블록에서 `_buildFreeTrialBanner` / `_buildPromoCodeCta` / `SnsEventCard` / 구 TODO 주석 블록 삭제 → `_buildRestoreOnly(l10n)` 만 남김 (복원 전용 모드) |
| `lib/src/screens/profile/profile_screen.dart` (최대 변경 — 177 LOC 삭제) | 프리미엄 섹션 전체 제거: `_buildPremiumSection`, `_buildPremiumStatusCard`, `_loadPremiumStatus`, 상태 변수 `_premiumTier`/`_premiumExpiresAt`/`_isLoadingPremium`, 코치마크 `_premiumCardKey` + 스텝, divider, SNS 이벤트 카드 섹션. 미사용 import `app_config.dart`, `premium_provider.dart`, `sns_event_card.dart` 제거 |
| `lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart` | `_loadPremiumBannerState()` 초입에 `if (!AppConfig.premiumEnabled) return;` 가드 추가 — 무료 체험 배너 미노출. `QuotaBadge` 호출부에서 `upgradeText`/`onUpgradePressed` 인자 제거 |

**합계**: +69 / -505 (순감 -436 LOC)

---

## 변경하지 않은 것

| 항목 | 이유 |
|------|------|
| `lib/src/config/app_config.dart` (`premiumEnabled = false`) | 플래그 유지 — 현재는 `ai_encyclopedia_screen._loadPremiumBannerState` 1곳의 배너 노출 가드로만 사용. IAP 복원 시 단일 변경 지점 |
| `lib/src/services/iap/iap_service.dart` | 구현 완료 상태 그대로 유지. App Store Connect 유료 계약 체결 후 premium_screen 주석 해제로 즉시 재활성 |
| `lib/src/screens/premium/promo_code_bottom_sheet.dart` | 파일 자체는 유지, 호출 경로만 단절 (unused file로 존재). `PERCH-XXXX-XXXX` 포맷은 공식 Offer Code로 전환 검토 필요 |
| `lib/src/router/app_router.dart` — `/home/premium` 라우트 | 라우트 정의 유지. `premium_screen`이 restore-only 진입점으로 동작하며, 직접 URL 진입 시 `initState`에서 `context.pop()` |
| 백엔드 API (`/premium/*`) | 서버 응답은 그대로. 클라이언트의 UX 표현만 변경 |
| 로컬라이제이션 나머지 키 (`premium_upgradeToPremium`, `quotaBadge_upgrade`, `visionQuotaBadge_upgrade` 등) | 문자열은 삭제하지 않고 유지 — IAP 재활성화 시 즉시 재사용. 현재는 dead string |
| `premium_screen.dart`의 `_buildFreeTrialBanner` / `_buildPromoCodeCta` / `_buildPlanSelector` 메서드 | 삭제하지 않고 `ignore_for_file: unused_element`로 보존 → revert 비용 최소화 |

---

## 복원 방법

유료 계약 체결 후 IAP 재활성화 시 2단계:

1. **플래그 전환**
   ```dart
   // lib/src/config/app_config.dart
   static const bool premiumEnabled = true;
   ```
   → AI 백과사전 무료 체험 배너 재노출.

2. **본 커밋 revert** — 업그레이드 CTA/paywall 동선, 프리미엄 섹션, 잠금 오버레이, 403 프리미엄 에러 UI 복원. 필요 시 l10n 문자열만 선택적으로 유지.

`premium_screen.dart`의 `_buildRestoreOnly` 블록을 `_buildPlanSelector` + `_buildCtaButton` + `_buildSecondaryActions`로 교체하고, App Store Connect에서 `perchcare_premium_monthly` / `_yearly` 상품을 "Ready to Submit"으로 만든다.

---

## 검증

### 정적 분석
- `flutter analyze` — 새 에러/경고 없음. `_openPremiumPaywall` / `_buildFreeTrialBanner` 등 미사용 메서드는 `ignore_for_file: unused_element` 또는 `// ignore: unused_element`로 의도적 침묵 처리.

### 수동 QA 체크리스트 (iPad Air M3 + Free 계정)
- [ ] **홈** — Free 사용자에게 "인사이트 업그레이드" 티저 카드 미노출. HealthSummaryCard는 기본(체중/BHI)만, 상세 섹션 자체가 렌더링되지 않음
- [ ] **AI 백과사전** — 무료 체험 배너 미노출. `QuotaBadge` exhausted 상태에서 업그레이드 버튼 미렌더링
- [ ] **건강체크 (403 재현)** — 쿼터 소진 시 "월간 한도 도달" 타이틀 + `Icons.hourglass_bottom` + 재시도 버튼 숨김 + "뒤로" 버튼만 노출
- [ ] **건강체크 기록 공유** — Free 계정에서 공유 시도 → "공유에 실패했어요" 스낵바 (페이월 리다이렉트 없음)
- [ ] **수의사 요약 공유** — 동일
- [ ] **프로필** — 프리미엄 섹션·SNS 이벤트 카드 섹션 미노출. 코치마크 스텝도 AddPet/FirstPet 2개만 표시
- [ ] **프리미엄 화면 딥링크** — `/home/premium` 직접 진입 시 즉시 pop

### 다국어 검증
- ko/en/zh 3개 로케일에서 403 에러 UX의 타이틀·본문 문구가 "월간 한도" 톤으로 일관되게 표시되는지 확인.

---

## 영향 범위 정리

**사용자 체감**
- Free 사용자: "업그레이드하면 더 쓸 수 있다"는 유도 신호가 UI에서 전반적으로 사라짐
- Free 사용자: 월간 쿼터 소진 시 "다음 달에 다시" 메시지 — 재구매/결제 경로 대신 시간 경과 해소
- 프리미엄 사용자: 변화 없음 (서버 `tier = 'premium'` 응답 시 동일 UX)

**Apple 리뷰어 관점**
- 정적 검사: IAP 외 결제 유도 CTA 부재
- 동적 검사: `/home/premium` 진입 시도 시 자동 pop, 프로모 코드 UI 미노출, "Upgrade" 버튼 0개
- 남아 있는 문자열(`premium_upgradeToPremium` 등)은 실행 경로에서 도달 불가 — dead string으로 존재
