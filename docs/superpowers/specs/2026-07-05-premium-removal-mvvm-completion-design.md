# 설계 스펙 — 프리미엄/SNS 이벤트 제거 · MVVM 전환 완성 · 펫 전환 버그 수정

- 날짜: 2026-07-05
- 상태: 사용자 설계 승인 완료 (스펙 리뷰 대기)
- 범위 결정 (사용자 확정):
  - 프리미엄: **앱 전부 제거 + 서버 쿼터는 비용 안전장치로 유지**
  - 샤오홍슈 캠페인 문서(docs/marketing/): **유지** (앱 코드의 SNS 이벤트 요소만 제거)
  - MVVM: **전 도메인 완성 — 단계별 진행**

---

## 배경

1. **펫 전환 버그**: 기록 탭에서 펫 선택기로 다른 펫을 탭하면 선택이 유지되지 않고 이전 펫으로 되돌아온다. 프로필 페이지에서만 정상 변경 가능. 근본 원인은 MVVM 미완성(아래 Stage 0).
2. **MVVM 현황**: CLAUDE.md의 "완료 5개 도메인" 중 실제 완료는 food/water뿐. weight는 절반(기록 탭 본체 `weight_detail_screen` 2,556줄이 완전 미전환), pet은 `pet_profile_detail_screen`이 Repository를 우회. 미전환 도메인: auth(8화면)·health_check(6화면)·ai_encyclopedia(1,372줄)·notification·profile(1,501줄)·locale·bhi·splash.
3. **프리미엄**: `AppConfig.premiumEnabled=false`로 paywall은 이미 사문화. 살아있는 것은 비전 쿼터 잠금 UI·프로모 코드 시트·쿼터 배지·429/403 처리·프리미엄 전용 인사이트/리포트 공유 게이팅. 서버(backend/)가 쿼터를 실제로 강제한다(백과사전 월 30회 → 429, 비전 월 10회 → 403, 리포트 공유 premium 전용 → 403).
4. **SNS 이벤트**: `sns_event_card.dart`(dead code), 건강체크 한도 다이얼로그의 "SNS로 연락하시면" 문구(라이브), l10n 키 3종, premium_screen의 dormant 복원용 코드.

---

## Stage 0 — 펫 전환 버그 즉시 수정

### 근본 원인 (조사 확정, high confidence)

- `weight_detail_screen.dart:197-217` `_switchPet()`: 탭 시 로컬 `_activePetId` setState + `_petCache.setActivePetId()` + `_petService.setActivePet()`만 호출 — **`activePetViewModelProvider`(Riverpod)는 갱신하지 않음**
- `weight_detail_screen.dart:360-367` build()의 동기화 가드: `ref.watch(activePetProvider)`의 펫 ≠ 로컬 `_activePetId`이면 `addPostFrameCallback`으로 `_switchPet(providerPet)` 실행 → **setState 리빌드 직후 stale provider 값(이전 펫)이 선택을 원복**
- 2차 피해: 원복 경로가 이전 펫으로 `PUT /pets/{id}/activate`를 다시 보내 서버 활성 펫까지 되돌림 (앱 재시작에도 이전 펫이 유지되는 이유)
- 프로필 페이지가 정상인 이유: `pet_profile_screen.dart:218-221`이 `ActivePetViewModel.switchPet()`(`active_pet_view_model.dart:24-29`)을 호출해 provider state 자체를 갱신

### 수정

- `_switchPet`의 탭 핸들러를 `ref.read(activePetViewModelProvider.notifier).switchPet(pet.id)` 호출로 교체. 로컬 영속화/서비스 직접 호출 제거.
- build()의 가드(provider → 로컬 동기화)는 유지 — provider가 갱신되면 가드가 화면 데이터를 리로드하는 올바른 단방향 흐름이 됨.
- 검증: 기록 탭에서 펫 전환 후 유지 여부, 홈·프로필과의 일관성, 앱 재시작 후 활성 펫 유지.

---

## Stage 1 — 프리미엄 + SNS 이벤트 제거

### 1-A. 앱: 삭제 대상 (전용 파일 7개)

| 파일 | 비고 |
|---|---|
| `lib/src/services/premium/premium_service.dart` | PremiumStatus/QuotaInfo 모델 + /premium/tier·activate (194줄) |
| `lib/src/services/iap/iap_service.dart` | in_app_purchase 래퍼, 구매/복원/서버검증 (281줄) |
| `lib/src/providers/premium_provider.dart` | premiumStatusProvider (37줄) |
| `lib/src/screens/premium/premium_screen.dart` | paywall, premiumEnabled=false로 즉시 pop되는 dead code (787줄) |
| `lib/src/screens/premium/promo_code_bottom_sheet.dart` | 프로모 코드 시트 — 프리미엄 제거로 존재 의미 소멸 (213줄) |
| `lib/src/widgets/quota_badge.dart` | QuotaBadge/VisionQuotaBadge (151줄) |
| `lib/src/widgets/sns_event_card.dart` | SNS 이벤트 카드, import 0건 고아 파일 (218줄) |

### 1-B. 앱: 수정 대상

- **라우터**: `app_router.dart` premium GoRoute(L218-224)+import, `route_names.dart` L34, `route_paths.dart` L41-42
- **초기화/수명주기**: `splash_screen.dart`(premiumStatusProvider 시딩 L133, IapService.initialize L366), `auth_service.dart`(로그인 IAP init L200, signOut/deleteAccount의 캐시 무효화 L216·L328, dispose L226), `auth_actions.dart`(invalidate L12)
- **config**: `app_config.dart` premiumEnabled 플래그 제거
- **health_check 5화면**:
  - `health_check_main_screen.dart` — `_isLocked`/`_hasVisionTrial`/`_visionRemaining`/`_loadPremiumStatus`, 잠금 카드 UI, VisionQuotaBadge, 한도 다이얼로그+PromoCodeBottomSheet(L153-232), "SNS로 연락" 문구(`healthCheck_trialExhaustedMessage_v2`), coach_hcTrial 스텝
  - `health_check_capture_screen.dart` — `_checkPremium()` 리다이렉트(L41-57)
  - `health_check_analyzing_screen.dart` — `_checkPremiumThenAnalyze`(L66-81), 사후 refresh+analytics(L136-144), **403 → 중립 한도 메시지로 유지**(L180-182·L332)
  - `vet_summary_screen.dart` — isFree 게이트 제거(L36-45)
  - `health_check_history_screen.dart` — 공유 isFree 게이트 제거(L196-205)
- **ai_encyclopedia_screen.dart** — `_premiumStatus`/`_isQuotaExhausted`/`_loadQuota`(L122-146), appBar QuotaBadge(L714-727), dead 프리미엄 배너(L153-180·L1100-1180), `/home/premium` push(L1151). **429 처리 2곳(L320-337·L516-531)은 중립 한도 메시지로 유지**
- **home 도메인** — `home_repository.dart`(getTier 병렬 호출·isPremium 분기 L160-186 제거, **weekly insight는 항상 조회**), `home_state.dart`/`home_view_model.dart`(isPremium 필드 제거), `home_screen.dart`(인사이트 프리미엄 게이트 L986 제거 → 전원 노출), `health_summary_card.dart`(isPremium 파라미터 제거, `_buildPremiumDetails` 상세 섹션 전원 노출)
- **부수**: `analytics_service.dart`(paywall_/purchase_/promo_code_/quota_/vision_trial 이벤트 메서드 L55-121), `coach_mark_service.dart`(screenPremium L21), `faq_screen.dart`(프리미엄 카테고리 q14-16), `terms_content.dart`(약관 4-2 프리미엄 조항·구독정보 수집 항목 — 개인정보처리방침의 일반 "이벤트, 프로모션 정보 제공" 마케팅 동의 조항은 유지), `icons.dart`(workspacePremium)
- **l10n**: `app_ko.arb`/`app_en.arb`/`app_zh.arb`에서 premium_(25)·paywall_(24)·quotaBadge_(3)·visionQuotaBadge_(3)·aiEncyclopedia_quotaExhausted*·healthCheck_trialExhausted*·healthCheck_freeTrialBadge·chatbot_premiumBanner/Upgrade·coach_hcTrial/premiumPlan/premiumPromo/profilePremium_*·faq_categoryPremium+q14-16·paywall_snsEvent*·sns_copied 등 약 80키 제거. **한도 안내용 중립 키 신설**(예: `quota_limitReachedTitle`, `quota_limitReachedMessage` — "이번 달 사용 한도에 도달했어요. 다음 달에 다시 이용할 수 있어요." ko/en/zh). `flutter gen-l10n` 재생성
- **의존성**: `pubspec.yaml` in_app_purchase 제거 → `flutter pub get` + iOS `pod install`. `ios/Runner.xcodeproj/project.pbxproj`의 수동 링크 StoreKit.framework 참조(AEA366DE/DF) 제거
- **테스트**: `home_view_model_test.dart`(isPremium mock/검증 제거), `models_serialization_test.dart`(HealthSummary premium 필드 테스트 — 모델 필드는 유지하므로 명칭만 정리)

### 1-C. 429/403 처리 정책 (유지)

서버 쿼터는 남으므로 클라이언트는 다음만 유지한다:
- 백과사전 429 → 중립 한도 메시지 표시 (2곳)
- 비전 403 → 중립 한도 메시지 표시 (2곳)
- 사전 차단 UI(잠금 카드·배지·프로모 유도)는 전부 제거 — 한도 도달은 서버 응답으로만 안내

### 1-D. 백엔드 (backend/)

| 대상 | 처리 |
|---|---|
| `routers/premium.py` + `schemas/premium.py` | 삭제, `main.py` 라우터 등록(L101) 제거 |
| `services/tier_service.py`, `dependencies.py::get_current_tier` | 삭제 — 전원 free 취급 |
| `services/quota_service.py` | **유지** — tier 조회 의존만 제거하고 전원에게 free 한도 적용 (백과사전 30/비전 10, `config.py`의 FREE_*_MONTHLY_LIMIT 그대로) |
| `routers/ai.py`, `routers/health_checks.py` | check_and_reserve_* 호출 유지 (쿼터 강제 지속), tier 분기만 제거 |
| `routers/reports.py` | premium 게이트(L93-98·L136-141) 제거 → 리포트 공유 전체 개방 |
| `jobs/weekly_insights.py` | premium 필터 제거 → 전체 사용자 대상 생성 (사용자 규모상 LLM 비용 미미) |
| `models/user_tier.py`, `models/premium_code.py` | 참조가 사라지면 모델 파일은 삭제. **DB 테이블은 보존** — drop 마이그레이션을 만들지 않는다 |
| `services/image_cleanup_service.py` | "프리미엄 만료 후 90일" 기준 제거 → 전원 동일 보존 정책으로 단순화 |

- **배포 순서**: 백엔드 먼저 배포 → 앱 릴리즈. (클라이언트 429/403 안내는 유지되므로 순서 리스크 낮음)
- **환경 주의** (메모리 노트): 백엔드는 staging, 배포 앱 .env는 production — 작업/배포 시 환경 일치 확인. Railway 환경변수 변경은 자동 재배포를 트리거하므로 환경변수는 건드리지 않는다(코드로만 처리).

### 1-E. 코드 밖 작업 (사용자 수동)

- App Store Connect: 구독 상품 2종(perchcare_premium_monthly/yearly) 판매 중단. 활성 구독자/프로모 코드 활성 사용자 존재 여부 확인 후 진행 권장.

### 1-F. 문서

- `docs/architecture/quota-system.md` — 서버 쿼터가 유지되므로 문서 유지하되 "프리미엄 tier" 부분에 제거 반영 갱신
- `docs/marketing/2026-04-xiaohongshu-2.0/` — **유지** (사용자 결정)
- CLAUDE.md — Premium/IAP 섹션 삭제·갱신 (gitignored이므로 로컬 파일만 수정)

---

## Stage 2 — weight 도메인 완성 + pet 구멍

1. **Repository 신설**: `ScheduleRepository`(ScheduleService 래핑), `DailyRecordRepository`(DailyRecordService 래핑) + `repository_providers.dart` 등록
2. **WeightRepository 보강**: weight_detail/weight_record가 쓰는 조회 경로(fetchLocalRecords, 서버 조회, PetLocalCacheService, BreedService.fetchBreedById) 흡수
3. **`weight_detail_screen`(2,556줄) 전환**: `WeightDetailViewModel` 신설 — 차트 데이터(주/월/년), 스케줄 CRUD, 데일리 레코드 CRUD, 활성 펫 연동을 ViewModel 상태로 이전. setState 14회 제거. 화면이 과대하므로 전환 과정에서 위젯 추출로 파일 분할 허용(기능 변경 없음)
4. **`weight_record_screen`**: 조회 경로를 ViewModel 경유로 (저장은 이미 weightAddViewModel)
5. **pet 구멍**: `pet_profile_detail_screen`(871줄) → 기존 `PetRepository` 사용으로 교체 (PetService.instance.createPet/updatePet/deletePet L768·L808·L820 + PetLocalCacheService 직접 호출 제거, PetAddViewModel과의 저장 로직 중복 해소). `pet_profile_screen.dart:35`의 AuthService.getProfile 직접 호출은 **Stage 4 auth 전환 시 정리(Stage 2에서는 보류)**, `home_screen` 잔존(AnalyticsService 1건은 cross-cutting 예외, 미사용 import 제거)
6. **공용 위젯**: `add_daily_record_bottom_sheet`(DailyRecordService → DailyRecordRepository provider 경유)

테스트: WeightDetailViewModel·신설 Repository mock 단위 테스트.

---

## Stage 3 — S/M 도메인

1. **notification (S)**: `NotificationRepository` + `NotificationViewModel`(AsyncNotifier). 실시간 Stream 구독은 ViewModel에서 `ref.onDispose` 정리. 화면 setState 7회 제거
2. **bhi (S)**: `BhiRepository` 신설, `bhi_provider.dart`는 Repository 경유로 (provider 이름 유지)
3. **locale (S~M)**: `LocaleProvider`(ChangeNotifier 싱글턴) → Riverpod Notifier. `api_client.dart:38`·`push_notification_service.dart:74`의 역참조는 locale 변경 시 서비스에 값을 push하는 setter 주입으로 교체. main.dart 초기화 경로 조정
4. **profile (M~L)**: `profile_screen.dart`(1,501줄) — 소셜 link/unlink/deleteAccount는 Stage 4 AuthRepository 선행이 필요하므로, Stage 3에서는 pet/locale 부분만 ViewModel 경유로 전환하고 auth 부분은 Stage 4에서 마무리
5. **splash (M)**: 부트스트랩 오케스트레이션(TokenService→ApiClient 순서 의존 유지)을 `appStartupProvider`(FutureProvider)로 추출, 화면은 애니메이션+라우팅만
6. **공용 위젯**: `breed_selector`(BreedService → provider 경유), `local_image_avatar`(LocalImageStorageService → provider 경유)

---

## Stage 4 — L 도메인

1. **auth**: `AuthRepository`(abstract+impl, AuthService 래핑 — 소셜 로그인 결과 DTO 정의) + `AuthViewModel`. 대상 8화면: login, email_login, signup, forgot_password 3종, profile_setup(+complete), pet_profile_screen 잔존. 로그인 성공 후 `hasPets()` 라우팅 분기가 화면마다 중복(login_screen:38, email_login_screen:86) — ViewModel/헬퍼로 일원화. 기존 `auth_actions.dart::performLogout`을 ViewModel로 승격. GoogleSignIn 등 플랫폼 SDK 호출은 Repository 내부로. profile_screen의 auth 부분 마무리
2. **health_check**: `ReportShareService` 신설(화면의 ApiClient 원시 호출 제거 — history:167·212, vet_summary:47) → `HealthCheckRepository`(HealthCheckService+HealthCheckStorageService+LocalImageStorageService 래핑, 로컬·서버 이중 동기화 캡슐화) → 캡처→분석→결과→저장 플로우용 ViewModel 설계 (5화면 상태 공유)
3. **ai_encyclopedia**: `ChatRepository`(AiEncyclopediaService+AiStreamService+ChatStorageService+ChatApiService 래핑, 서버 세션·로컬 저장 병합 캡슐화) + SSE 스트리밍용 Notifier(chunk 수신 시 state 갱신, setState 23회 제거). 1,372줄 화면 위젯 분할 허용

---

## Cross-cutting 정책

- **CoachMarkService·AnalyticsService는 View 직접 호출 허용 예외로 명문화** (11곳/8곳 산재 — UI 온보딩·분석 이벤트는 View 관심사). CLAUDE.md 작성 규칙에 예외 조항 추가
- 레거시 provider alias 유지 원칙 지속 (`activePetProvider` 등)
- 각 단계 완료 기준: `flutter analyze` 0 이슈(신규 기준) + `flutter test` 통과 + 해당 화면 수동 검증 → 단계별 커밋

## 테스트 전략

- 신설 ViewModel마다 Repository mock 단위 테스트 (`test/view_models/pet/pet_list_view_model_test.dart` 패턴)
- Stage 0: 펫 전환 수동 재현 검증 + ActivePetViewModel 연동 회귀 테스트(가능 시 위젯 테스트)
- Stage 1: 한도(429/403) 응답 시 중립 메시지 노출 확인, gen-l10n 3언어 빌드 확인, iOS 빌드(`flutter build ios --no-codesign`)로 StoreKit 제거 검증

## 리스크 및 완화

| 리스크 | 완화 |
|---|---|
| 활성 구독자/프로모 코드 사용자 존재 시 혜택 소멸 | 진행 전 App Store Connect + user_tier/premium_code 테이블 확인 (사용자 수동) |
| 백엔드·앱 배포 시차 | 백엔드 먼저 배포, 클라 429/403 안내 유지로 완충 |
| weight_detail 2,556줄 전환 중 회귀 | 기능 변경 없는 순수 구조 전환 원칙, 차트/스케줄/기록 시나리오 수동 검증 목록 작성 |
| l10n 대량 삭제로 빌드 깨짐 | 키 제거 → gen-l10n → analyze를 단계 내 최우선 검증으로 |
| Railway 환경변수 변경 시 의도치 않은 재배포 | 환경변수 불변경 — 코드로만 처리 |
