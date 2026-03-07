# Perch Care 수익화 PRD

**작성일:** 2026-03-07  
**문서 상태:** Draft v1  
**작성 목적:** Perch Care의 첫 상용 수익화 모델을 정의하고, 앱 내 결제 도입부터 전환 퍼널, 계정 권한, 지표, 출시 기준까지 실행 가능한 수준으로 정리한다.

---

## 1. 문서 요약

Perch Care는 이미 `free/premium` 티어, 프리미엄 코드 활성화, AI Vision 건강체크 잠금, 프리미엄 상태 조회, AI 사용 로그 집계를 갖추고 있다. 그러나 현재 프리미엄은 일반 사용자가 직접 구매할 수 없는 상태이며, 무료 기능의 가치 경계도 느슨해 전환 압력이 약하다.

이번 PRD의 목표는 다음 3가지를 동시에 달성하는 것이다.

1. 일반 사용자가 앱 내에서 Premium을 직접 구매할 수 있게 한다.
2. 핵심 무료 가치를 유지하면서도 Premium 결제 이유를 분명하게 만든다.
3. AI 원가를 통제 가능한 수준으로 관리하면서 반복 매출 구조를 만든다.

핵심 전략은 `Freemium + 단일 Premium 구독`이다.

- Free는 기록과 기본 건강 관리 경험을 충분히 제공한다.
- Premium은 `AI Vision 건강체크`, `고급 AI 응답`, `더 깊은 개인화`, `향후 리포트/내보내기`에 집중한다.
- 기존 프리미엄 코드는 일반 판매 수단이 아니라 `프로모션`, `제휴`, `CS 보상`, `내부 운영` 채널로 유지한다.

---

## 2. 현재 상태

### 2-1. 제품 현황

- iOS App Store 출시 상태
- 가입 사용자 250+명
- 한국어/영어/중국어 지원
- 핵심 킬러 기능은 체중 기록 및 건강 추적
- AI 기능은 백과사전 Q&A와 Vision 건강체크 두 축으로 운영

### 2-2. 이미 구현된 기반

| 항목 | 현재 상태 | 관련 파일 |
|------|----------|----------|
| 사용자 티어 | `free/premium` 지원 | `backend/app/models/user_tier.py` |
| 프리미엄 코드 | 생성/활성화/관리자 관리 가능 | `backend/app/routers/premium.py` |
| 프리미엄 상태 조회 | 앱에서 tier 조회 가능 | `lib/src/services/premium/premium_service.dart` |
| 프리미엄 화면 | 현재는 코드 입력 중심 | `lib/src/screens/premium/premium_screen.dart` |
| Vision 잠금 | Premium 전용으로 차단 | `backend/app/routers/health_checks.py` |
| AI 차등화 | Free/Premium 모델, 토큰, RAG 범위 차등 | `backend/app/services/ai_service.py` |
| 사용량 분석 | AI 사용량/예상 비용 집계 가능 | `backend/app/routers/premium.py` |

### 2-3. 현재 문제

1. Premium이 존재하지만 `구매 가능한 상품`이 아니다.
2. 코드 입력 기반 구조는 일반 사용자 결제 경험으로 부적절하다.
3. 무료 AI 백과사전은 현재 사실상 사용량 상한이 없어 Premium 전환 유인이 약하다.
4. 결제 퍼널 분석 이벤트가 없어 어떤 surface가 매출에 기여하는지 측정하기 어렵다.
5. Premium 가치가 `Vision 잠금 해제`에 과도하게 의존하고 있어 장기적으로 상품 확장이 약하다.

---

## 3. 문제 정의

Perch Care는 건강 기록 앱이면서 AI 기반 건강 보조 도구다. 사용자는 기록 기능 때문에 들어오지만, 돈을 지불하는 순간은 보통 다음 두 경우에 발생한다.

1. 반려조 건강에 대한 불안이 즉시 해소되어야 할 때
2. 기록 데이터를 더 깊게 해석하고 싶을 때

현재 제품은 이 순간에 맞는 결제 흐름이 없다. 사용자는 잠금 메시지를 보더라도 즉시 결제하지 못하고, 프리미엄 코드가 없는 이상 전환이 사실상 막혀 있다.

즉, 현재의 문제는 "프리미엄 기능이 없는 것"이 아니라 "프리미엄이 판매 가능한 제품으로 정리되어 있지 않은 것"이다.

---

## 4. 목표와 비목표

### 4-1. Product Goals

1. App Store / Play Store 인앱 구독을 도입해 누구나 Premium을 구매할 수 있게 한다.
2. Free와 Premium의 가치 경계를 명확히 만든다.
3. AI 원가를 고려했을 때 Premium 가입자가 늘수록 손익 구조가 개선되도록 만든다.
4. 결제 퍼널을 측정 가능하게 만들어 이후 가격/메시지/제한 실험이 가능하도록 한다.

### 4-2. Business Goals

출시 후 첫 60일 기준 목표:

- 유료 구독자 20명 이상 확보
- Paywall view -> purchase 전환율 `>= 2.0%`
- 연간 구독 비중 `>= 30%`
- Premium 가입자 30일 유지율 `>= 70%`
- Premium 1인당 월 AI 원가가 순매출의 `<= 35%`

### 4-3. Guardrails

- 체중 기록 완료율이 수익화 도입 전 대비 `5% 이상` 악화되지 않을 것
- 무료 사용자의 AI 백과사전 사용량이 `20% 이상` 급락하지 않을 것
- 결제/권한 관련 CS 이슈가 출시 첫 2주 동안 전체 DAU의 `2% 이하`일 것

### 4-4. Non-Goals

이번 범위에 포함하지 않는 것:

- 광고 수익화
- 다단계 요금제 (`Basic`, `Pro`, `Family` 등)
- 펫당 과금
- 평생권 판매
- 오프라인 병원 예약/보험/커머스 수익화
- 중국 서드파티 앱마켓 전용 결제 수단 도입

---

## 5. 대상 사용자

### Persona A. 기록 중심 사용자

- 체중, 사료, 물 기록을 꾸준히 남긴다.
- 건강지표를 보고 이상 여부를 확인하고 싶다.
- 결제 동기는 "기록을 더 잘 해석하고 싶다"에 가깝다.

### Persona B. 불안 해소형 사용자

- 증상/사진이 생겼을 때 즉시 조언을 원한다.
- 결제 동기는 "지금 당장 판단이 필요하다"에 가깝다.
- Vision 건강체크가 가장 강한 전환 트리거다.

### Persona C. 고관여 보호자

- 여러 마리의 새를 돌보거나, 데이터와 리포트를 중시한다.
- 결제 동기는 "시간 절약"과 "정리된 분석"이다.
- 향후 PDF 리포트, 추세 분석, 내보내기 기능의 타깃이다.

---

## 6. 상품 전략

### 6-1. 기본 원칙

1. 무료 핵심 경험은 유지한다.  
   기록 기능을 과도하게 잠그면 앱 전체 신뢰와 리텐션이 무너진다.

2. 결제 가치는 "불안 해소"와 "해석 깊이"에 집중한다.  
   Premium은 AI가 특히 잘 드러나는 영역에 붙인다.

3. 상품은 단순하게 유지한다.  
   초기에는 `Premium 1개 + 월간/연간`만 운영한다.

4. 권한은 계정 단위로 부여한다.  
   펫당 과금은 다펫 사용자 반발과 CS 복잡도를 키운다.

### 6-2. Launch Packaging

| 플랜 | 가격 가설 | 대상 |
|------|----------|------|
| Premium Monthly | `₩5,900 / $4.99` | 가볍게 써보고 싶은 사용자 |
| Premium Yearly | `₩49,000 / $39.99` | 꾸준히 기록하는 사용자 |

연간 플랜을 기본 추천 옵션으로 노출한다.

### 6-3. Launch Benefit Table

| 기능 | Free | Premium |
|------|------|---------|
| 체중/사료/물 기록 | 무제한 | 무제한 |
| 기본 차트/BHI | 제공 | 제공 |
| AI 백과사전 | 일일 3회 | 사실상 무제한 |
| AI 백과사전 응답 품질 | 기본형 | 구조화 + 긴 응답 + 더 긴 개인화 문맥 |
| 개인화 RAG 범위 | 최근 7일 | 최근 30일 |
| AI Vision 건강체크 | 1회 체험 또는 잠금 | 무제한 |
| 건강체크 히스토리 | 제한적 | 전체 활용 |
| 향후 PDF/병원용 요약 리포트 | 미제공 | 제공 예정 |

### 6-4. 무료 체험 정책

출시 기본안:

- 플랫폼 구독 무료체험은 기본값으로 두지 않는다.
- 대신 `계정당 1회 무료 Vision 체험` 또는 `첫 Vision 결과 일부 미리보기` 중 하나를 채택한다.

이유:

- Vision은 단가가 가장 높은 기능이라 무료체험 비용이 직접적으로 커진다.
- Perch Care의 결제 유인은 "일단 써보면 좋은 기능"보다 "지금 필요한 기능"에 가깝다.
- 1회 샘플은 가치 전달에는 충분하고 비용 통제도 쉽다.

---

## 7. UX 및 전환 퍼널

### 7-1. 핵심 전환 Surface

1. `AI Vision 진입 직전`
2. `AI 백과사전 일일 한도 도달 시점`
3. `프로필 > Premium 카드`
4. `건강체크 결과 화면 하단 업셀`
5. `AI 백과사전 상단 배너`

### 7-2. Paywall 원칙

- 코드 입력 화면이 아니라 `실제 결제용 paywall`이어야 한다.
- 첫 화면에는 가격보다 `얻는 결과`를 먼저 보여준다.
- 복잡한 비교표보다 `불안 해소`, `이상 징후 조기 발견`, `기록 기반 정리`를 전면에 둔다.
- 보조 CTA로 `프로모션 코드 입력`을 제공한다.
- `복원하기(Restore Purchases)`를 명확히 제공한다.

### 7-3. 권장 Paywall 정보 구조

1. 헤드라인  
   `사진과 기록으로 더 정확하게 건강 상태를 파악하세요`

2. 핵심 가치 3개
   - 무제한 AI Vision 건강체크
   - 기록 기반 맞춤형 AI 해석
   - 이상 징후를 더 일찍 발견할 수 있는 분석

3. 플랜 선택
   - 연간 플랜 강조
   - 월간 플랜 보조

4. 구매 CTA
   - `Premium 시작하기`

5. 보조 액션
   - `복원하기`
   - `프로모션 코드 입력`

### 7-4. 전환 흐름

```text
[Feature Blocked]
    ->
[Paywall View]
    ->
[Plan Select]
    ->
[Store Checkout]
    ->
[Purchase Success]
    ->
[Entitlement Refresh]
    ->
[Blocked Feature Resume]
```

결제 성공 후에는 사용자를 원래 막혀 있던 기능으로 즉시 복귀시켜야 한다.

---

## 8. 제품 요구사항

### 8-1. Client Requirements

### A. Premium Screen 개편

현재 `lib/src/screens/premium/premium_screen.dart`는 코드 입력 중심이다. 이를 아래 구조로 변경한다.

- 기본 상태: paywall
- 보조 진입: 프로모션 코드 입력 바텀시트 또는 서브 화면
- 스토어 상품 정보 표시
- 연간/월간 선택 UI
- 구매 중 상태, 실패 상태, 복원 상태 표시

### B. AI Quota UI

AI 백과사전 화면에 Free 사용자의 남은 일일 횟수를 표시한다.

예:

- `오늘 2회 남음`
- `오늘 무료 사용량을 모두 사용했어요`

### C. Vision Trial UX

무료 사용자는 아래 둘 중 하나를 경험해야 한다.

- 첫 1회 무료 Vision 분석
- 결과 미리보기 이후 상세 잠금

선택 기준은 원가와 전환율 실험 결과에 따라 결정한다.

### D. Post-purchase Recovery

구매 직후:

- Premium 배지가 즉시 갱신되어야 한다.
- 막혀 있던 화면을 다시 진입하지 않고 이어서 사용할 수 있어야 한다.
- 네트워크 지연 시 로딩 상태와 재시도 경로가 필요하다.

### 8-2. Backend Requirements

### A. Store Subscription Entitlement

현재는 `promo code` 기반 활성화만 존재한다. 여기에 스토어 기반 entitlement를 추가한다.

권장 방식:

- 클라이언트는 StoreKit / Google Play Billing으로 결제를 시작
- 서버는 영수증 또는 거래 정보를 검증해 `user_tiers`를 갱신
- 서버가 최종 entitlement source of truth가 된다

### B. AI Free Quota Enforcement

현재 AI 백과사전은 rate limit은 있으나 `무료 사용량 제한`은 없다. 다음 제약을 추가한다.

- Free: 하루 3회
- Premium: 사실상 무제한
- 기준 시각: 사용자 로컬 날짜 또는 UTC 기준 중 하나를 명확히 고정

권장:

- 초기 구현은 `UTC day bucket`
- 이후 필요 시 사용자 locale/timezone 기반으로 확장

### C. Admin Visibility

관리자 영역 또는 관리자 API에서 다음이 보여야 한다.

- 결제 source별 Premium 사용자 수
- 일별 신규 구독 수
- 일별 갱신/만료/취소 수
- Free/Premium별 AI 호출 수와 원가
- 프로모션 코드 사용 성과

### 8-3. Policy Requirements

- 앱 내 디지털 기능 판매는 Apple/Google 인앱 결제 정책을 따른다.
- 웹 결제 우회는 MVP 범위에 포함하지 않는다.
- 환불/복원/만료 안내 문구를 store 정책에 맞춰 노출한다.

---

## 9. 데이터 모델 변경안

### 9-1. `user_tiers` 확장

현행 컬럼에 아래 필드 추가를 권장한다.

| 컬럼 | 타입 | 목적 |
|------|------|------|
| `source` | string | `free`, `promo_code`, `app_store`, `play_store`, `admin` |
| `store_product_id` | string nullable | 결제 상품 식별 |
| `store_original_transaction_id` | string nullable | 스토어 원거래 식별 |
| `auto_renew_status` | bool nullable | 자동 갱신 상태 |
| `grace_period_expires_at` | datetime nullable | 유예 기간 종료 |
| `last_verified_at` | datetime nullable | 마지막 스토어 검증 시각 |

### 9-2. 신규 테이블: `subscription_transactions`

구독 상태와 별도로 원시 거래 로그를 남긴다.

| 컬럼 | 설명 |
|------|------|
| `id` | PK |
| `user_id` | 사용자 |
| `store` | `apple` / `google` |
| `product_id` | 상품 ID |
| `transaction_id` | 거래 ID |
| `original_transaction_id` | 원거래 ID |
| `event_type` | purchase / renewal / cancel / expire / refund / restore |
| `purchased_at` | 거래 시각 |
| `expires_at` | 만료 시각 |
| `payload_json` | 검증 응답 원본 |
| `created_at` | 적재 시각 |

필요 이유:

- CS 대응
- 환불/중복 구매 추적
- 스토어 webhook 및 재검증 디버깅

### 9-3. 신규 테이블: `ai_usage_quotas` 또는 일별 로그 집계

구현은 두 방식 중 하나를 선택한다.

1. 별도 quota 테이블 유지
2. `AiEncyclopediaLog`를 일별 집계해 실시간 카운트

초기 권장안:

- 별도 테이블 없이 `AiEncyclopediaLog` 집계로 시작
- 부하가 커지면 캐시/요약 테이블 도입

---

## 10. API 변경안

### 10-1. 신규/변경 엔드포인트

#### `GET /premium/tier`

현재 응답:

- `tier`
- `premium_expires_at`

확장 응답:

- `tier`
- `premium_expires_at`
- `source`
- `store_product_id`
- `quota`
  - `ai_encyclopedia_daily_limit`
  - `ai_encyclopedia_daily_used`
  - `vision_trial_remaining`

#### `POST /premium/activate`

- 기존 유지
- 사용처를 `프로모션 코드 활성화`로 명확히 한정

#### `POST /premium/purchases/verify`

클라이언트가 스토어 거래 정보 전달 -> 서버 검증 -> entitlement 반영

예시 요청:

```json
{
  "store": "apple",
  "product_id": "perchcare_premium_yearly",
  "transaction_id": "1000001234567890",
  "receipt_payload": "..."
}
```

예시 응답:

```json
{
  "success": true,
  "tier": "premium",
  "premium_expires_at": "2027-03-07T00:00:00Z",
  "source": "app_store"
}
```

#### `POST /premium/purchases/restore`

- 서버 재검증 후 현재 entitlement 반환

#### `GET /ai/quota`

- 남은 무료 사용량 조회
- 앱 최초 진입 시 또는 AI 화면 진입 시 사용

### 10-2. Webhook / Server Jobs

중장기적으로 아래 이벤트 처리 필요:

- Apple server notifications
- Google RTDN

MVP에서는 `클라이언트 구매 후 서버 검증`으로 시작하고, 안정화 후 webhook 자동화로 확장한다.

---

## 11. Analytics Requirements

현재 `AnalyticsService`에는 결제 퍼널 이벤트가 없다. 다음 이벤트를 추가한다.

| 이벤트명 | 파라미터 |
|---------|---------|
| `paywall_view` | `source`, `feature`, `tier` |
| `plan_selected` | `source`, `plan`, `price_locale` |
| `checkout_started` | `store`, `product_id`, `source` |
| `purchase_success` | `store`, `product_id`, `source`, `is_restore` |
| `purchase_failed` | `store`, `product_id`, `reason` |
| `restore_success` | `store`, `tier` |
| `premium_feature_blocked` | `feature`, `source_screen` |
| `ai_quota_viewed` | `remaining`, `tier` |
| `ai_quota_reached` | `feature`, `used_count` |
| `vision_trial_used` | `remaining_after` |
| `promo_code_entry_opened` | `source` |
| `promo_code_activated` | `campaign_code_prefix` |

### 11-1. KPI Dashboard

필수 대시보드:

1. Paywall별 view -> checkout -> purchase 퍼널
2. 플랜별 구매 비중 (월/년)
3. source별 매출 기여도
4. Premium 가입자 유지율
5. Free vs Premium AI 호출량
6. Free/Premium 유저당 AI 원가

---

## 12. 실험 계획

### Experiment 1. Free AI 백과사전 한도

- A안: 하루 3회
- B안: 하루 5회

측정:

- AI 재방문율
- paywall 전환율
- Premium 가입률
- Free 사용자 이탈률

### Experiment 2. Vision 체험 방식

- A안: 계정당 1회 무료 Vision
- B안: 결과 일부 미리보기 후 잠금

측정:

- Vision 진입 -> paywall 전환율
- 체험 후 구매 전환율
- AI 원가

### Experiment 3. Paywall Copy

- A안: 기능 중심
- B안: 결과 중심

권장 기본값은 B안이다.

---

## 13. 출시 단계

### Phase 1. Monetization MVP

범위:

- iOS 우선 출시, Android는 앱 배포 준비 시 동일 구조 재사용
- 인앱 구독 상품 생성
- Premium screen paywall 개편
- purchase / restore / verify 구현
- `GET /premium/tier` 확장
- 결제 퍼널 analytics 추가

출시 기준:

- iOS sandbox / TestFlight 구매 검증 통과
- 복원하기 동작 확인
- 결제 후 tier 갱신 지연 5초 이하

### Phase 2. Quota & Conversion Optimization

범위:

- AI 백과사전 무료 일일 한도 도입
- Vision 체험 로직 도입
- blocked state copy 최적화
- 관리자 KPI 대시보드 정리

### Phase 3. Premium Value Expansion

범위:

- PDF 내보내기
- 병원 방문용 요약 리포트
- 건강 변화 요약 카드
- 주간/월간 인사이트

---

## 14. 리스크와 대응

| 리스크 | 설명 | 대응 |
|--------|------|------|
| 전환은 낮고 반감만 큰 경우 | 무료 기능을 과하게 잠그면 리텐션 하락 | 기록 기능은 무료 유지, AI만 단계적 제한 |
| 결제 성공 후 권한 반영 지연 | UX 불신 발생 | 서버 검증 응답을 즉시 반영하고 백그라운드 재검증 |
| AI 원가 초과 | 헤비 유저가 비용을 키움 | free quota, rate limit, premium 원가 모니터링 |
| 스토어 정책 이슈 | 디지털 기능 판매 정책 위반 위험 | 인앱 결제 채널 우선, 웹 결제 우회 제외 |
| CS 증가 | 결제/복원/환불 문의 증가 | 거래 로그 저장, restore flow, FAQ 준비 |

---

## 15. 출시 체크리스트

### Product

- [ ] Free/Premium 혜택 문구 확정
- [ ] 월간/연간 가격 확정
- [ ] Vision 체험 방식 확정
- [ ] FAQ에 결제/복원/환불/만료 안내 추가

### Client

- [ ] paywall UI 구현
- [ ] 결제 및 복원 플로우 구현
- [ ] quota 표시 UI 구현
- [ ] blocked -> purchase -> resume UX 구현
- [ ] analytics 이벤트 추가

### Backend

- [ ] entitlement 검증 API 구현
- [ ] `user_tiers` 확장 마이그레이션
- [ ] 거래 로그 테이블 추가
- [ ] AI 무료 한도 집계/검증 구현
- [ ] 관리자 사용량/매출 분석 API 확장

### QA

- [ ] 신규 구매
- [ ] 복원 구매
- [ ] 만료 후 free 복귀
- [ ] 프로모션 코드 활성화
- [ ] AI quota 도달 시 차단
- [ ] 네트워크 실패 시 재시도
- [ ] 다국어 문구 검수

---

## 16. 최종 권고안

Perch Care의 첫 수익화는 `광고`가 아니라 `Premium 구독`으로 가야 한다. 이유는 제품의 핵심 차별점이 AI와 개인화 건강 해석에 있고, 이미 기술적 기반도 상당 부분 준비되어 있기 때문이다.

출시 기준 상품은 다음으로 고정한다.

- Free: 기록 기능 무제한 + AI 백과사전 일일 제한
- Premium Monthly: `₩5,900 / $4.99`
- Premium Yearly: `₩49,000 / $39.99`

구현 우선순위는 다음 순서가 가장 합리적이다.

1. paywall + 인앱 결제 도입
2. entitlement 검증 및 복원
3. AI 무료 사용량 제한
4. 결제 퍼널 측정
5. Premium 가치 확장

핵심은 "기능을 잠그는 것"이 아니라 "필요한 순간에 자연스럽게 결제되게 만드는 것"이다.
