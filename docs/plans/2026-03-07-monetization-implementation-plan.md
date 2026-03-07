# Perch Care 수익화 구현 계획서

**작성일:** 2026-03-07
**문서 상태:** Draft v1
**관련 문서:** [수익화 PRD](./2026-03-07-monetization-prd.md)
**구현 방식:** Flutter `in_app_purchase` 패키지 직접 구현 + FastAPI 서버 사이드 영수증 검증

---

## Context

Perch Care는 250+ 사용자의 반려조 건강관리 앱으로, `free/premium` 티어와 프리미엄 코드 시스템이 이미 구현되어 있지만, 일반 사용자가 직접 구매할 수 있는 결제 수단이 없다.

**서버 환경 현황:**
- **Production** — 250+ 실사용자 데이터, `main` 브랜치 auto-deploy
- **Staging** — 개발/테스트용 (유저 5명, 테스트 데이터만 존재), `dev` 브랜치 auto-deploy

**목표:** PRD Phase 1~3 전체를 `in_app_purchase` 패키지 직접 구현 방식으로 개발한다. staging에서 개발/검증 후 production에 반영하는 기존 워크플로우를 따른다.

### 이미 구현된 기반

| 항목                   | 현재 상태                                                          | 파일                                                |
| ---------------------- | ------------------------------------------------------------------ | --------------------------------------------------- |
| 사용자 티어 모델       | `free/premium` 지원, 만료 자동 처리                                | `backend/app/models/user_tier.py`                   |
| Tier Service           | `get_user_tier()`, `activate_premium_code()` (upsert + FOR UPDATE) | `backend/app/services/tier_service.py`              |
| 프리미엄 라우터        | 코드 활성화 + Admin 관리 + 사용량 분석                             | `backend/app/routers/premium.py`                    |
| AI 차등화              | Free=gpt-4o-mini/1024/7일, Premium=gpt-4.1-nano/2048/30일          | `backend/app/services/ai_service.py`                |
| Vision 잠금            | `tier != "premium"` → 403                                          | `backend/app/routers/health_checks.py:168`          |
| Flutter Premium 서비스 | 5분 캐시, `getTier()`, `activateCode()`                            | `lib/src/services/premium/premium_service.dart`     |
| Premium 화면           | 코드 입력 중심 UI                                                  | `lib/src/screens/premium/premium_screen.dart`       |
| Firebase Analytics     | 기본 이벤트만 (결제 이벤트 없음)                                   | `lib/src/services/analytics/analytics_service.dart` |
| AI 로그                | `AiEncyclopediaLog`, `AiVisionLog` (user_id + created_at 인덱스)   | `backend/app/models/`                               |

### 없는 것

- `in_app_purchase` 패키지 (Flutter 미설치)
- 스토어 영수증 검증 API
- AI 무료 사용량 제한 (quota)
- 결제 퍼널 analytics 이벤트

---

## Pre-Phase: 개발 워크플로우 및 Production 배포 준비

환경 분리는 이미 완료되어 있다. 개발은 staging(dev)에서 진행하고, 검증 후 production(main)에 반영한다.

### 개발 → 배포 흐름

```
1. dev 브랜치에서 코드 개발 (Flutter + Backend)
   ↓
2. staging에서 자동 배포 → DB 마이그레이션/기능 테스트
   ↓
3. 검증 완료 후 dev → main PR/merge
   ↓
4. production 배포 직전:
   - production DB 백업 (pg_dump)
   - production Railway에 IAP 환경변수 추가
   ↓
5. main merge → production auto-deploy
   - 마이그레이션 자동 실행
```

### Production 배포 시 주의사항

1. **DB 마이그레이션 안전 절차**
   - staging에서 마이그레이션 먼저 실행/검증 (테스트 데이터 5명)
   - production 배포 전 **반드시 DB 백업** (pg_dump)
   - Migration 013, 014는 컬럼/테이블 추가만 하므로 기존 데이터에 breaking change 없음
   - 기존 데이터 backfill: `activated_code IS NOT NULL` → `source='promo_code'`, 나머지 → `source='free'`

2. **환경변수 추가 (production Railway)**
   - 기존 `JWT_SECRET`, `ADMIN_API_KEY` 등은 **변경하지 않음** (사용자 세션 보호)
   - Apple/Google IAP 관련 신규 환경변수만 추가

3. **신규 config.py 필드**

```python
# Apple IAP (App Store Server API v2)
apple_key_id: str = ""
apple_issuer_id: str = ""
apple_private_key: str = ""       # Base64 인코딩된 .p8 키
apple_bundle_id: str = "com.perch.perchCare2"

# Google IAP
google_package_name: str = "com.perchcare.app"
google_service_account_json: str = ""  # Base64 인코딩된 서비스 계정 JSON
```

### 수정 파일

- `backend/app/config.py` — Apple/Google IAP 설정 필드 추가
- `backend/.env.example` — 신규 환경변수 문서화

---

## Phase 1: Monetization MVP

### 1-1. 스토어 상품 설정 (수동 작업)

**App Store Connect (iOS 우선):**

- Subscription Group: "Perch Care Premium"
- `perchcare_premium_monthly` — ₩5,900 / $4.99
- `perchcare_premium_yearly` — ₩49,000 / $39.99
- Sandbox 테스터 계정 생성
- App Store Server Notifications V2 URL 사전 설정

**Google Play Console (Android 병렬):**

- 동일 상품 ID로 구독 상품 생성
- 서비스 계정 JSON 키 다운로드

### 1-2. DB 스키마 확장

**Migration 013: `user_tiers` 확장**

| 신규 컬럼                       | 타입                           | 목적                                         |
| ------------------------------- | ------------------------------ | -------------------------------------------- |
| `source`                        | `String(20)`, default `'free'` | `free/promo_code/app_store/play_store/admin` |
| `store_product_id`              | `String(100)`, nullable        | 스토어 상품 ID                               |
| `store_original_transaction_id` | `String(200)`, nullable        | 스토어 원거래 ID                             |
| `auto_renew_status`             | `Boolean`, nullable            | 자동 갱신 상태                               |
| `grace_period_expires_at`       | `DateTime(tz)`, nullable       | 유예 기간 종료                               |
| `last_verified_at`              | `DateTime(tz)`, nullable       | 마지막 스토어 검증 시각                      |

- 기존 데이터 backfill: `activated_code IS NOT NULL` → `source='promo_code'`, 나머지 → `source='free'`
- 수정 파일: `backend/app/models/user_tier.py`

**Migration 014: `subscription_transactions` 신규 테이블**

| 컬럼                      | 설명                                            |
| ------------------------- | ----------------------------------------------- |
| `id`                      | UUID PK                                         |
| `user_id`                 | FK → users                                      |
| `store`                   | `apple` / `google`                              |
| `product_id`              | 상품 ID                                         |
| `transaction_id`          | 거래 ID (indexed)                               |
| `original_transaction_id` | 원거래 ID (indexed)                             |
| `event_type`              | `purchase/renewal/cancel/expire/refund/restore` |
| `purchased_at`            | 거래 시각                                       |
| `expires_at`              | 만료 시각                                       |
| `payload_json`            | 검증 응답 원본 (TEXT)                           |
| `created_at`              | 적재 시각                                       |

- 신규 파일: `backend/app/models/subscription_transaction.py`

### 1-3. 스토어 검증 서비스 (백엔드 핵심)

**신규 파일:** `backend/app/services/store_verification_service.py`

**Apple 검증 (App Store Server API v2):**

1. `.p8` 키로 ES256 JWT 생성 (apple_key_id, apple_issuer_id 사용)
2. `GET https://api.storekit.itunes.apple.com/inApps/v1/transactions/{transactionId}` 호출
3. JWS signedTransactionInfo 디코딩 → `productId`, `originalTransactionId`, `expiresDate`, `autoRenewStatus` 추출
4. Sandbox 환경 자동 감지 (environment 필드)

**Google 검증:**

1. 서비스 계정 JSON으로 인증
2. `GET androidpublisher/v3/applications/{package}/purchases/subscriptions/{id}/tokens/{token}` 호출
3. `orderId`, `expiryTimeMillis`, `autoRenewing` 추출

**의존성 추가:** `backend/requirements.txt`에 `PyJWT>=2.8.0`

### 1-4. Tier Service 확장

**수정 파일:** `backend/app/services/tier_service.py`

기존 `activate_premium_code()` 패턴(upsert + FOR UPDATE)을 재사용하여 추가:

```python
async def activate_store_subscription(db, user_id, store, product_id,
    transaction_id, original_transaction_id, expires_at, auto_renew, raw_payload) -> UserTier:
    # 1. subscription_transactions에 event_type='purchase' 로그
    # 2. user_tiers UPSERT (source='app_store'/'play_store', 스토어 필드 설정)
    # 3. 기존 promo_code 만료일과 비교 → 더 긴 쪽 유지

async def restore_store_subscription(db, user_id, store, ...) -> UserTier:
    # 동일 로직, event_type='restore'
```

### 1-5. 신규 API 엔드포인트

**수정 파일:** `backend/app/routers/premium.py`, `backend/app/schemas/premium.py`

| 엔드포인트                        | 설명                                                                        |
| --------------------------------- | --------------------------------------------------------------------------- |
| `POST /premium/purchases/verify`  | 클라이언트 → 서버 검증 → entitlement 반영                                   |
| `POST /premium/purchases/restore` | 구매 복원 (재설치 후 등)                                                    |
| `GET /premium/tier` (확장)        | 기존 응답에 `source`, `store_product_id`, `auto_renew_status`, `quota` 추가 |

**verify 요청/응답:**

```json
// Request
{"store": "apple", "product_id": "perchcare_premium_yearly", "transaction_id": "..."}

// Response
{"success": true, "tier": "premium", "premium_expires_at": "...", "source": "app_store"}
```

### 1-6. Flutter IAP 서비스

**의존성 추가:** `pubspec.yaml`에 `in_app_purchase: ^3.2.0`

**신규 파일:** `lib/src/services/iap/iap_service.dart`

싱글톤 패턴 (기존 `PremiumService` 패턴 따름):

- `initialize()` — `purchaseStream` 리스닝 시작 + 상품 로드
- `buySubscription(ProductDetails)` — 구독 구매 시작
- `restorePurchases()` — 구매 복원
- `_handlePurchaseUpdates()` — 스트림 이벤트 처리
- `_verifyAndDeliver()` — 서버 검증 호출 → `PremiumService.invalidateCache()` → UI 콜백

**초기화 위치:** `lib/src/screens/splash/splash_screen.dart`의 서비스 초기화 블록에 `IapService.instance.initialize()` 추가

### 1-7. Paywall 화면 리디자인

**수정 파일:** `lib/src/screens/premium/premium_screen.dart` (전면 재작성)

**화면 구조:**

```
[AppBar]
[Hero 섹션] "사진과 기록으로 더 정확하게 건강 상태를 파악하세요"
[핵심 가치 3개] 아이콘 + 설명
  - 무제한 AI Vision 건강체크
  - 기록 기반 맞춤형 AI 해석
  - 이상 징후 조기 발견 분석
[플랜 선택 카드] 연간(기본 추천) / 월간
[구매 CTA] "Premium 시작하기"
[보조 액션] "복원하기" / "프로모션 코드 입력"
[로딩/에러 오버레이]
```

**신규 파일:** `lib/src/screens/premium/promo_code_bottom_sheet.dart`

- 기존 코드 입력 UI를 바텀시트로 추출

**동작:**

- 구매 성공 → 성공 다이얼로그 → `context.pop()`으로 원래 기능 복귀
- 복원 성공 → 캐시 갱신 → 상태 반영
- 에러 → SnackBar 또는 인라인 에러 + 재시도

### 1-8. PremiumService 확장

**수정 파일:** `lib/src/services/premium/premium_service.dart`

`PremiumStatus` 모델에 필드 추가:

- `source` (String?)
- `storeProductId` (String?)
- `autoRenewStatus` (bool?)
- `isStoreSubscription` getter

### 1-9. Analytics 결제 이벤트

**수정 파일:** `lib/src/services/analytics/analytics_service.dart`

추가 이벤트: `paywall_view`, `plan_selected`, `checkout_started`, `purchase_success`, `purchase_failed`, `restore_success`, `premium_feature_blocked`, `promo_code_entry_opened`, `promo_code_activated`

### 1-10. Paywall 네비게이션 포인트 업데이트

기존에 프리미엄 화면으로 이동하는 곳에 `source`/`feature` 컨텍스트 전달:

| 파일                                 | 위치                   | source         |
| ------------------------------------ | ---------------------- | -------------- |
| `health_check_main_screen.dart`      | `_showPremiumDialog()` | `vision_lock`  |
| `health_check_analyzing_screen.dart` | 403 에러 CTA           | `vision_403`   |
| `ai_encyclopedia_screen.dart`        | 프리미엄 배너          | `ai_banner`    |
| `profile_screen.dart`                | 프리미엄 카드          | `profile_card` |

### 1-11. 다국어 문자열

**수정 파일:** `lib/l10n/app_ko.arb`, `app_en.arb`, `app_zh.arb`

Paywall 관련 키 20+ 개 추가 (헤드라인, 혜택, 플랜명, 가격, CTA, 에러 메시지 등)

### Phase 1 파일 총 목록

| 작업 | 파일                                                              |
| ---- | ----------------------------------------------------------------- |
| 수정 | `backend/app/models/user_tier.py`                                 |
| 수정 | `backend/app/services/tier_service.py`                            |
| 수정 | `backend/app/routers/premium.py`                                  |
| 수정 | `backend/app/schemas/premium.py`                                  |
| 수정 | `backend/app/config.py`                                           |
| 수정 | `backend/requirements.txt`                                        |
| 수정 | `backend/.env.example`                                            |
| 신규 | `backend/app/models/subscription_transaction.py`                  |
| 신규 | `backend/app/services/store_verification_service.py`              |
| 신규 | `backend/alembic/versions/013_add_store_subscription_fields.py`   |
| 신규 | `backend/alembic/versions/014_add_subscription_transactions.py`   |
| 수정 | `pubspec.yaml`                                                    |
| 수정 | `lib/src/screens/premium/premium_screen.dart`                     |
| 수정 | `lib/src/services/premium/premium_service.dart`                   |
| 수정 | `lib/src/services/analytics/analytics_service.dart`               |
| 수정 | `lib/src/screens/splash/splash_screen.dart`                       |
| 수정 | `lib/src/screens/health_check/health_check_main_screen.dart`      |
| 수정 | `lib/src/screens/health_check/health_check_analyzing_screen.dart` |
| 수정 | `lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart`     |
| 수정 | `lib/src/screens/profile/profile_screen.dart`                     |
| 수정 | `lib/l10n/app_ko.arb`, `app_en.arb`, `app_zh.arb`                 |
| 신규 | `lib/src/services/iap/iap_service.dart`                           |
| 신규 | `lib/src/screens/premium/promo_code_bottom_sheet.dart`            |

---

## Phase 2: Quota & Conversion Optimization

### 2-1. AI 백과사전 무료 일일 한도

**설계 결정:** 별도 quota 테이블 없이 `AiEncyclopediaLog` 일별 집계 사용 (이미 `user_id` + `created_at` 인덱스 존재, 250 사용자 규모에서 충분)

**신규 파일:** `backend/app/services/quota_service.py`

- `get_encyclopedia_usage_today(db, user_id)` → `{daily_limit: 3, daily_used: N, remaining: M}` (UTC day bucket)
- `check_encyclopedia_quota(db, user_id, tier)` → premium이면 항상 True, free면 3회 체크

**수정 파일:** `backend/app/routers/ai.py`

- `POST /encyclopedia`, `POST /encyclopedia/stream` 진입 시 quota 체크 추가
- 초과 시 `429 Too Many Requests` ("일일 무료 사용량을 초과했습니다")

**신규 엔드포인트:** `GET /ai/quota`

- free: `{tier, ai_encyclopedia: {daily_limit, daily_used, remaining}, vision_trial_remaining}`
- premium: limit/remaining = null (무제한)

**`GET /premium/tier` 확장:** 응답에 `quota` 필드 포함 (한 번의 호출로 tier + quota 조회)

### 2-2. Vision 1회 무료 체험

**추가 함수 (`quota_service.py`):**

- `get_vision_trial_remaining(db, user_id)` → `AiVisionLog` 전체 카운트 기반, 계정당 1회
- `check_vision_access(db, user_id, tier)` → premium이면 True, free면 남은 체험 체크

**수정 파일:** `backend/app/routers/health_checks.py` (168번째 줄)

- 기존: `if tier != "premium": raise 403`
- 변경: `if not await check_vision_access(db, user_id, tier): raise 403`

### 2-3. Flutter Quota UI

**수정 파일:** `lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart`

- 화면 진입 시 `GET /ai/quota` 호출
- 남은 횟수 배지: "오늘 2회 남음"
- 소진 시 입력 영역 → 차단 상태 + "Premium으로 업그레이드" CTA
- 429 응답 핸들링

**신규 파일:** `lib/src/widgets/quota_badge.dart`

### 2-4. Vision 체험 UX

**수정 파일:** `lib/src/screens/health_check/health_check_main_screen.dart`

- 기존 이진 잠금 (`_isLocked = status.isFree`) → quota 기반 3단 상태:
  1. Premium → 자유 접근
  2. Free + 체험 남음 → "무료 1회 체험 가능" 배지 + 접근 허용
  3. Free + 체험 소진 → 잠금 다이얼로그 (기존)
- 체험 완료 후 결과 화면에 업셀 메시지

### 2-5. 관리자 KPI API

**수정 파일:** `backend/app/routers/premium.py`

| 엔드포인트                         | 반환 데이터                                                          |
| ---------------------------------- | -------------------------------------------------------------------- |
| `GET /admin/subscriptions/summary` | source별 프리미엄 사용자 수, 일별 신규/갱신/만료/취소                |
| `GET /admin/conversion/funnel`     | 전체/무료/프리미엄 사용자, source별 구매 비중, 평균 전환 소요일      |
| `GET /admin/ai-cost`               | Free/Premium별 AI 호출 수, 사용자당 예상 비용, 구독자당 비용 vs 매출 |

### 2-6. 추가 Analytics 이벤트

- `ai_quota_viewed(remaining, tier)`
- `ai_quota_reached(feature, used_count)`
- `vision_trial_used(remaining_after)`

### Phase 2 파일 총 목록

| 작업 | 파일                                                          |
| ---- | ------------------------------------------------------------- |
| 신규 | `backend/app/services/quota_service.py`                       |
| 수정 | `backend/app/routers/ai.py`                                   |
| 수정 | `backend/app/routers/health_checks.py`                        |
| 수정 | `backend/app/routers/premium.py`                              |
| 수정 | `backend/app/schemas/premium.py`                              |
| 수정 | `lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart` |
| 수정 | `lib/src/screens/health_check/health_check_main_screen.dart`  |
| 수정 | `lib/src/services/analytics/analytics_service.dart`           |
| 수정 | `lib/l10n/app_ko.arb`, `app_en.arb`, `app_zh.arb`             |
| 신규 | `lib/src/widgets/quota_badge.dart`                            |

---

## Phase 3: Premium Value Expansion

### 3-1. 건강 리포트 웹 링크 공유 ✅

> **변경 사항:** PDF 생성 → 웹 링크 공유 방식으로 변경. weasyprint / Docker 시스템 패키지 불필요. JWT 서명 토큰 기반 공유 URL 생성 → 브라우저에서 HTML 리포트 뷰.

**백엔드:**

- `backend/app/services/report_service.py` — Jinja2 HTML 템플릿 렌더링 → HTML string 반환 (`generate_health_html()`, `generate_vet_summary_html()`)
- `backend/app/routers/reports.py` — JWT 토큰 기반 공유 엔드포인트:
  - `POST /reports/share/health/{pet_id}` — Premium 전용, 공유 토큰 생성 → `share_url` 반환
  - `POST /reports/share/vet-summary/{pet_id}` — Premium 전용, 공유 토큰 생성 → `share_url` 반환
  - `GET /reports/view/{token}` — 공개 (토큰 자체 검증), HTML 리포트 렌더링
- `backend/app/templates/reports/health_report.html` — 웹 최적화 (반응형, viewport meta, max-width)
- `backend/app/templates/reports/vet_summary.html` — 웹 최적화
- 토큰 만료: 7일, PyJWT + `settings.jwt_secret` 재사용
- ~~weasyprint~~ 불필요, ~~Dockerfile 시스템 패키지 변경~~ 불필요

**Flutter:**

- `pubspec.yaml`에 `share_plus` 추가
- 건강체크 히스토리 화면 AppBar에 공유 아이콘 → `share_plus`로 웹 URL 공유
- Premium 전용 (free → paywall)

### 3-2. 병원 방문용 요약 리포트 ✅

**백엔드:**

- `report_service.py`의 `generate_vet_summary_html()` — 최근 30일 체중 추이, 건강체크, BHI, 이상 소견, 일상 기록 요약
- `POST /reports/share/vet-summary/{pet_id}` 엔드포인트 (3-1과 동일 라우터)

**Flutter:**

- 신규: `lib/src/screens/health_check/vet_summary_screen.dart` — 설명 카드 + CTA 버튼
- 건강체크 히스토리 AppBar의 병원 아이콘에서 진입
- Premium 전용 + `share_plus`로 웹 URL 공유

### 3-3. 건강 변화 요약 카드

**백엔드:**

- `GET /pets/{pet_id}/health-summary` — 체중 추이, BHI 추이, 이상 소견, 급여 일관성 점수
- Free: 기본 요약 / Premium: 상세 카드

**Flutter:**

- 신규: `lib/src/widgets/health_summary_card.dart`
- 홈 화면 프리미엄 영역에 표시
- Free는 프리뷰 카드 + 잠금 오버레이 + paywall CTA

### 3-4. 주간/월간 인사이트

**백엔드:**

- `backend/app/scheduler.py`에 주간 인사이트 생성 Job 추가 (매주 월요일 09:00 UTC)
- `GET /pets/{pet_id}/insights` 엔드포인트
- 필요 시 `insights` 테이블 마이그레이션 추가

**Flutter:**

- 홈 화면 인사이트 섹션 (premium only)
- FCM 푸시 알림으로 주간 인사이트 전달 (기존 `firebase_messaging` 활용)

### Phase 3 (3-1, 3-2) 파일 총 목록

| 작업 | 파일                                                               | 상태 |
| ---- | ------------------------------------------------------------------ | ---- |
| 신규 | `backend/app/services/report_service.py`                           | ✅   |
| 신규 | `backend/app/routers/reports.py` (JWT 토큰 공유 방식)              | ✅   |
| 신규 | `backend/app/templates/reports/health_report.html` (웹 최적화)     | ✅   |
| 신규 | `backend/app/templates/reports/vet_summary.html` (웹 최적화)       | ✅   |
| 수정 | `backend/app/main.py` (reports 라우터 등록)                        | ✅   |
| ~~수정~~ | ~~`backend/requirements.txt` (`weasyprint`)~~ — 불필요         | N/A  |
| ~~수정~~ | ~~`backend/Dockerfile` (시스템 패키지)~~ — 불필요               | N/A  |
| 신규 | `lib/src/screens/health_check/vet_summary_screen.dart`             | ✅   |
| 수정 | `lib/src/screens/health_check/health_check_history_screen.dart`    | ✅   |
| 수정 | `lib/src/router/app_router.dart`                                   | ✅   |
| 수정 | `lib/src/router/route_names.dart`                                  | ✅   |
| 수정 | `lib/src/router/route_paths.dart`                                  | ✅   |
| 수정 | `lib/l10n/app_ko.arb`, `app_en.arb`, `app_zh.arb` (리포트 키 9개) | ✅   |
| 수정 | `pubspec.yaml` (`share_plus`) — Phase 1에서 이미 추가              | ✅   |

### Phase 3 (3-3, 3-4) 파일 목록 (미구현)

| 작업 | 파일                                                           |
| ---- | -------------------------------------------------------------- |
| 수정 | `backend/app/scheduler.py`                                     |
| 신규 | `backend/alembic/versions/015_add_insights_table.py` (필요 시) |
| 신규 | `lib/src/widgets/health_summary_card.dart`                     |
| 수정 | `lib/src/screens/home/home_screen.dart`                        |

---

## 공통 설계 사항

### 프로모 코드 + IAP 공존 정책

- `user_tiers.source` 필드로 활성화 경로 구분
- 동시 활성일 경우 `premium_expires_at`이 더 긴 쪽 유지
- 기존 `POST /premium/activate` (코드 활성화) 그대로 유지
- Admin revoke 시 어떤 source를 revoke하는지 명시

### Webhook (Phase 1 이후 확장)

MVP에서는 **클라이언트 → 서버 검증** 방식으로 시작. 안정화 후:

- Apple: `POST /webhooks/apple` — JWS 서명 검증 → `DID_RENEW`, `EXPIRED`, `REFUND` 등 처리
- Google: `POST /webhooks/google` — Pub/Sub 메시지 검증 → `SUBSCRIPTION_RENEWED`, `CANCELED` 등 처리
- 모든 이벤트 `subscription_transactions`에 로깅

### 에러 핸들링 & 엣지 케이스

1. **결제 중 네트워크 실패:** `in_app_purchase`가 pending 트랜잭션 큐잉 → 다음 앱 실행 시 `purchaseStream`에서 재방출
2. **서버 검증 실패:** 최대 3회 지수 백오프 재시도 → 실패 시 에러 UI + 수동 재시도 경로
3. **앱 재설치:** "복원하기" 플로우 → 스토어에서 활성 구독 재조회 → 서버 재검증
4. **구독 만료 (앱 열린 상태):** `PremiumService` 5분 캐시 → 다음 갱신 시 `tier: 'free'` 반영
5. **코드 + IAP 동시 활성화:** upsert 패턴으로 중복 행 방지, 만료일 비교로 긴 쪽 유지
6. **Sandbox vs Production:** 트랜잭션의 `environment` 필드로 자동 감지, 적절한 Apple API 엔드포인트 사용

---

## 구현 순서 (Phase 1 내)

1. Backend: DB 마이그레이션 (013, 014) — 추가만, breaking change 없음
2. Backend: `config.py` 설정 + `store_verification_service.py`
3. Backend: `tier_service.py` 신규 함수
4. Backend: `premium.py` 엔드포인트 + 스키마 확장
5. Flutter: `in_app_purchase` 의존성 추가
6. Flutter: `IapService` 구현
7. Flutter: `PremiumService` 모델 확장
8. Flutter: Paywall 화면 리디자인
9. Flutter: `AnalyticsService` 결제 이벤트
10. Flutter: 네비게이션 포인트 연동
11. 테스트: iOS Sandbox 결제 플로우 검증
12. 테스트: TestFlight 배포 + 내부 테스트
13. Production 배포

---

## 검증 체크리스트

### Phase 1 검증

- [ ] iOS Sandbox에서 월간/연간 구매 성공
- [ ] 구매 후 즉시 tier 갱신 확인 (5초 이내)
- [ ] "복원하기"로 재설치 후 프리미엄 복원
- [ ] 프로모션 코드 활성화 기존 기능 정상 동작
- [ ] 구매 후 막혀있던 Vision 기능 즉시 접근 가능
- [ ] Firebase Analytics에서 결제 퍼널 이벤트 수신 확인
- [ ] Admin API로 구독자 수/거래 로그 조회 가능

### Phase 2 검증

- [ ] Free 사용자 AI 백과사전 3회 후 429 차단
- [ ] Premium 사용자 AI 백과사전 무제한 사용
- [ ] Free 사용자 Vision 1회 체험 후 잠금
- [ ] Quota 배지 표시 정확 ("오늘 N회 남음")
- [ ] 관리자 KPI API 응답 정확

### Phase 3 (3-1, 3-2) 검증

- [ ] `POST /reports/share/health/{petId}` → `share_url` 반환 확인
- [ ] `POST /reports/share/vet-summary/{petId}` → `share_url` 반환 확인
- [ ] 브라우저에서 공유 URL 열기 → HTML 리포트 렌더링 확인
- [ ] 모바일 브라우저에서 반응형 레이아웃 확인
- [ ] 만료 토큰 → 에러 HTML 페이지 표시
- [ ] Free 사용자 → 403 차단
- [ ] Flutter 공유 버튼 → share sheet에 URL 전달
- [ ] Flutter 병원 요약 화면 → 공유 기능 정상 동작

### Phase 3 (3-3, 3-4) 검증 (미구현)

- [ ] 건강 변화 카드 홈 화면 표시
- [ ] 주간 인사이트 스케줄러 정상 동작
