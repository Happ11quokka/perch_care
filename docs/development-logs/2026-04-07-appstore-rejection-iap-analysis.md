# App Store 리뷰 리젝 분석 — Guideline 3.1.1 (In-App Purchase)

**날짜**: 2026-04-07
**Submission ID**: 875ed59f-faa4-45a5-a66b-0570c6856211
**리뷰 디바이스**: iPad Air 11-inch (M3)
**버전**: 2.0
**상태**: Bug Fix Submission (다음 업데이트에서 수정 가능)

---

## 리젝 사유 요약

Apple이 **동일한 가이드라인(3.1.1)으로 2건**을 지적했다. 둘 다 "IAP 외의 수단으로 유료 기능을 해제/접근"하는 것이 문제.

### 이슈 1: 프로모 코드로 프리미엄 기능 해제

> "The app uses promo codes to unlock premium features."

**현재 구현 상태:**
- `PERCH-XXXX-XXXX` 형식의 자체 프로모 코드 시스템 운영
- `POST /premium/activate` 엔드포인트로 백엔드에서 코드 검증 후 프리미엄 활성화
- UI: `PromoCodeBottomSheet` (lib/src/screens/premium/promo_code_bottom_sheet.dart)
- 페이월 화면에서 프로모 코드 입력이 **메인 CTA**로 배치됨 (premium_screen.dart:252)

**Apple의 요구:**
- 자체 프로모 코드 시스템 **제거** 필요
- 할인/무료 접근을 제공하려면 App Store Connect의 **Offer Codes** (공식 IAP 오퍼 코드) 사용

### 이슈 2: 앱 외부에서 구매한 디지털 콘텐츠 접근

> "The app accesses digital content purchased outside the app, such as premium, but that content isn't available to purchase using In-App Purchase."

**현재 구현 상태:**
- IAP 코드가 구현되어 있으나 **의도적으로 비활성화** 상태 (사업자등록 전 단계)
  - premium_screen.dart:257-262에서 IAP 관련 UI 주석 처리
  - `_buildPlanSelector`, `_buildCtaButton`, `_buildSecondaryActions` 모두 주석
- 프리미엄 기능(AI 건강체크, AI 백과사전)은 프로모 코드로만 활성화 가능
- 결과적으로 유료 기능이 존재하지만 IAP로 구매할 수 없는 상태

**Apple의 요구:**
- 앱 내 유료 디지털 콘텐츠/서비스는 **반드시 IAP로 구매 가능**해야 함
- 외부 구매 콘텐츠 접근은 허용하되, **동일 콘텐츠가 IAP로도 구매 가능**해야 함 (가이드라인 3.1.3(b))

---

## 영향 받는 코드 범위

### 프로모 코드 관련 (제거 또는 수정 대상)
| 파일 | 역할 |
|------|------|
| `lib/src/screens/premium/promo_code_bottom_sheet.dart` | 프로모 코드 입력 바텀시트 |
| `lib/src/screens/premium/premium_screen.dart` (L252, L585-619) | 프로모 코드 CTA 버튼, 보조 액션 |
| `lib/src/services/premium/premium_service.dart` (L177-191) | `activateCode()` API 호출 |
| `lib/src/providers/premium_provider.dart` | `activateCode()` 노티파이어 |
| `lib/src/services/analytics/analytics_service.dart` (L96-100) | 프로모 코드 분석 이벤트 |
| 로컬라이제이션 파일들 | `premium_code*`, `paywall_promoCode` 문자열 |

### IAP 관련 (활성화 대상)
| 파일 | 역할 |
|------|------|
| `lib/src/services/iap/iap_service.dart` | IAP 서비스 (구현 완료, 작동 확인 필요) |
| `lib/src/screens/premium/premium_screen.dart` (L257-262) | 주석 처리된 IAP UI 복원 |
| App Store Connect | 구독 상품 등록 (`perchcare_premium_monthly`, `perchcare_premium_yearly`) |

### 프리미엄 기능 게이팅 (변경 불필요)
| 파일 | 역할 |
|------|------|
| `health_check_capturing_screen.dart` | AI 건강체크 쿼터 제한 |
| `ai_encyclopedia_screen.dart` | AI 백과사전 쿼터 제한 |
| `lib/src/widgets/quota_badge.dart` | 쿼터 표시 위젯 |

---

## 해결 방안 분석

### 방안 A: IAP 활성화 + 프로모 코드 완전 제거 (권장)

**장점**: Apple 가이드라인 완전 충족, 가장 안전한 접근
**작업 내용**:
1. App Store Connect에서 구독 상품 2종 등록 (monthly, yearly)
2. premium_screen.dart에서 IAP UI 주석 해제 (Plan Selector + CTA + Secondary Actions)
3. 프로모 코드 관련 UI/로직 제거 또는 숨김 처리
4. 무료 체험은 Apple의 Free Trial 또는 Introductory Offer로 대체
5. 할인 코드가 필요하면 App Store Connect의 Offer Codes 사용

**주의**: App Store Connect에서 구독 상품이 "Ready to Submit" 상태여야 IAP가 작동함

### 방안 B: IAP 활성화 + 프로모 코드를 Apple Offer Code로 전환

**장점**: 기존 마케팅 플로우 유지 가능
**작업 내용**:
1. 방안 A의 1-2번 동일
2. 자체 프로모 코드 대신 `SKPaymentQueue.presentCodeRedemptionSheet()` 사용
3. 프로모 코드 바텀시트를 Apple 공식 코드 교환 시트로 교체
4. 백엔드의 `/premium/activate` 엔드포인트는 유지하되, Apple 서버 검증으로 변경

### 방안 C: 프리미엄 기능 자체를 제거 (최소 작업)

**장점**: 사업자등록 완료 전 빠른 통과 가능
**작업 내용**:
1. 프로모 코드 시스템 제거
2. 프리미엄 게이팅 로직 제거 (모든 기능 무료 개방)
3. 페이월 화면 제거 또는 "Coming Soon" 처리
4. 사업자등록 후 v2.1에서 IAP 도입

---

## 추가 참고사항

### "Bug Fix Submission" 옵션
Apple이 이 건을 "Bug Fix Submission"으로 분류했기 때문에:
- **현재 버전을 그대로 통과시키고 싶다면**: App Store Connect에서 회신하여 "다음 업데이트에서 수정하겠다"고 요청 가능
- **단, 다음 제출 시 반드시 수정되어야 함**

### 사업자등록 상태 확인 필요
- IAP를 활성화하려면 **유료 앱 계약** (Paid Applications Agreement)이 체결되어 있어야 함
- App Store Connect > Agreements, Tax, and Banking에서 상태 확인 필요
- 사업자등록이 아직 안 되어 있다면 방안 C가 현실적

### US 스토어프론트 외부 링크 관련
- 미국 스토어에서는 외부 결제 링크 허용 가능 (2024년 정책 변경)
- 그러나 한국/중국 등 다른 스토어프론트에서는 여전히 IAP 필수
- 글로벌 출시 시 IAP 구현이 안전한 선택

---

## 결론

핵심 문제는 **"유료 기능이 있는데 IAP로 구매할 수 없고, 자체 프로모 코드로만 해제 가능"**이라는 점이다.

**즉시 조치**: App Store Connect에서 회신하여 Bug Fix 통과 요청 가능
**근본 해결**: IAP 활성화(방안 A 또는 B) 또는 프리미엄 기능 임시 제거(방안 C) 중 사업자등록 상태에 따라 선택
