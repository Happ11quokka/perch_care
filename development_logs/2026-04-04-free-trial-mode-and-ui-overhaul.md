# 무료 체험 모드 전환 + UI 전면 개선

> 구현일: 2026-04-04

## 배경
사업자 등록 전이라 IAP 인앱 구독을 비활성화하고, 현재 AI 기능을 "무료 체험 중"으로 전환.
프로모션 코드는 SNS 이벤트로 계속 운영하며, 연락처를 프리미엄/프로필 화면에 표시.

---

## 1. Backend — 챗봇 무료 응답을 프리미엄 품질로 통합

### 변경 파일
- `backend/app/services/ai_service.py`

### 변경 내용
| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| `_build_system_prompt()` | free → `_FREE_FORMAT` (8줄 요약) | 모든 티어에 `_PREMIUM_FORMAT` (구조화 응답) |
| `_select_model()` | free → `gpt-4o-mini`, 1024 토큰 | 모든 티어에 `gpt-4.1-nano`, 2048 토큰 |
| `lookback_days` | free → 7일, premium → 30일 | 모든 티어에 30일 |
| DeepSeek 중국어 보충 | premium + 중국어만 | 중국어 질문이면 무조건 적용 |

### 비고
- 모든 변경에 `TODO(post-registration)` 주석 추가 — 사업자 등록 후 tier 분기 복원 가능
- `tier` 파라미터는 API 호환성을 위해 유지 (호출부 변경 없음)

---

## 2. 비전 체크 쿼터 배지 UI 개선

### 문제
- 기존: 정적 "무료 1회 체험" 텍스트 배지가 `_buildModeCard()` 안에서 GlobalKey 중복 사용
- GlobalKey는 위젯 트리에서 유일해야 하므로, 마지막 카드(먹이 안정성)에만 렌더링됨

### 해결

#### 2a. VisionQuota 모델 추가
- `lib/src/services/premium/premium_service.dart`
- `EncyclopediaQuota`와 동일 패턴: `isUnlimited`, `isExhausted`, `isWarning` (임계값: 3회)

#### 2b. VisionQuotaBadge 위젯 추가
- `lib/src/widgets/quota_badge.dart`
- 기존 `QuotaBadge`와 동일 3단계 상태: 초록(정상) → 주황(경고, <=3) → 빨강(소진)

#### 2c. 배지 배치 변경
- 개별 모드 카드 안에서 제거
- 모드 카드 목록 상단 헤더 행("검사 대상을 선택하세요" 옆)에 한 번만 배치
- 4개 모드 공통으로 "30회 남음" 배지가 보임

---

## 3. 프리미엄 화면 재구성 (IAP 비활성화)

### 변경 파일
- `lib/src/screens/premium/premium_screen.dart`

### 변경 전 (build 구조)
```
_buildPlanSelector()      → 월간/연간 플랜 선택
_buildCtaButton()         → "Premium 시작하기" 구매 버튼
_buildSecondaryActions()  → 구매 복원 | 프로모션 코드
```

### 변경 후
```
_buildFreeTrialBanner()   → 초록 배너 "AI 비전 체크와 AI 챗봇은 무료 체험 중입니다"
_buildPromoCodeCta()      → 그래디언트 CTA "프로모션 코드 입력" (메인 버튼으로 격상)
SnsEventCard()            → SNS 이벤트 연락처 카드
_buildRestoreOnly()       → 구매 복원 버튼만 유지
```

### 비고
- 기존 IAP 메서드(`_buildPlanSelector`, `_buildCtaButton`, `_buildSecondaryActions`)는 코드에 보존, 호출만 주석 처리
- `TODO(post-registration)` 주석으로 재활성화 지점 표시
- 코치마크: `_planSelectorKey` 제거, `_promoCodeButtonKey` 중심으로 변경

---

## 4. SNS 이벤트 공유 위젯 신규 생성

### 신규 파일
- `lib/src/widgets/sns_event_card.dart`

### SNS 연락처
| 플랫폼 | 값 | 탭 동작 |
|--------|-----|---------|
| Email | limdongxian1207@gmail.com | `mailto:` (url_launcher) |
| WeChat (微信) | dxxxxxxxxx1207 | 클립보드 복사 (AppSnackBar) |
| Instagram | perchcare | instagram.com 웹 열기 |
| 小红书 | 639474187 | xiaohongshu.com 웹 열기 |

### 언어별 강조 순서
- **한국어/영어**: Instagram, Email을 상단 (강조 스타일)
- **중국어**: 小红书, WeChat을 상단 (강조 스타일)

### 배치 위치
- 프리미엄 화면: 프로모션 코드 CTA 아래
- 프로필 화면: "앱 지원" 섹션과 "계정 관리" 섹션 사이

---

## 5. 소진 다이얼로그 업데이트

### 변경 파일
- `lib/src/screens/health_check/health_check_main_screen.dart` (`_showPremiumDialog()`)

### 변경 내용
| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 아이콘 | `Icons.workspace_premium` | `Icons.card_giftcard` |
| 메시지 | "프리미엄을 구독하시면..." | "프로모션 코드를 입력하거나 SNS로 연락하시면..." |
| 액션 버튼 | "프리미엄 활성화" → 페이월 이동 | "프로모션 코드 입력" → PromoCodeBottomSheet 직접 호출 |

---

## 6. 의존성 추가

### pubspec.yaml
- `url_launcher: ^6.3.1` 추가 — SNS 링크 열기용

---

## 7. 로컬라이제이션 추가

### 신규 키 (ko/en/zh 3개 파일)
- `visionQuotaBadge_normal` — "{count}회 남음"
- `visionQuotaBadge_exhausted` — "체험 소진"
- `visionQuotaBadge_upgrade` — "코드 입력"
- `paywall_freeTrialBanner` — "현재 AI 비전 체크와 AI 챗봇은 무료 체험 중입니다"
- `paywall_freeTrialSubtext` — "프로모션 코드를 입력하면 더 많은 혜택을 받을 수 있습니다"
- `paywall_snsEventTitle` — "SNS 이벤트"
- `paywall_snsEventDescription` — "팔로우 / 친구추가 후 DM으로 프로모션 코드를 받으세요!"
- `healthCheck_trialExhaustedMessage_v2` — 프로모션 코드/SNS 안내 메시지
- `healthCheck_trialExhaustedAction_promo` — "프로모션 코드 입력"
- `sns_copied` — "{label} 복사됨"

---

## 변경 파일 목록

| 파일 | 변경 유형 |
|------|-----------|
| `backend/app/services/ai_service.py` | 수정 — 응답 품질 통합 |
| `lib/src/services/premium/premium_service.dart` | 수정 — VisionQuota 모델 추가 |
| `lib/src/widgets/quota_badge.dart` | 수정 — VisionQuotaBadge 위젯 추가 |
| `lib/src/widgets/sns_event_card.dart` | **신규** — SNS 이벤트 카드 |
| `lib/src/screens/premium/premium_screen.dart` | 수정 — IAP 비활성화 + 무료 체험 UI |
| `lib/src/screens/health_check/health_check_main_screen.dart` | 수정 — 배지 + 다이얼로그 |
| `lib/src/screens/profile/profile_screen.dart` | 수정 — SNS 섹션 추가 |
| `lib/l10n/app_ko.arb` | 수정 — 신규 키 10개 |
| `lib/l10n/app_en.arb` | 수정 — 신규 키 10개 |
| `lib/l10n/app_zh.arb` | 수정 — 신규 키 10개 |
| `pubspec.yaml` | 수정 — url_launcher 추가 |
