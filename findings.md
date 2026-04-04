# perch_care 프로젝트 코드 리뷰 Findings

> 리뷰 일자: 2026-03-20 | Flutter 19개 스킬 기준 + 백엔드 보안 리뷰
> 수정 일자: 2026-03-21 | Flutter 6개 + 백엔드 보안 6개 + Riverpod 마이그레이션 (Phase 0-5)

---

## CRITICAL (즉시 수정 필요)

### C-1. IDOR 취약점 — 레코드 엔드포인트 소유권 미검증 `수정 완료`

- **위치:** `backend/app/routers/food_records.py`, `water_records.py`, `weights.py`, `health_checks.py`
- **문제:** pet_id 기반 레코드 CRUD에서 `current_user.id`와 pet 소유권 비교 없음
- **수정 내용:**
  - `dependencies.py`에 `verify_pet_ownership` 공통 의존성 추가
  - 4개 record 라우터 전체 엔드포인트에 `Depends(verify_pet_ownership)` 적용
- **수정일:** 2026-03-21

### C-2. 비밀번호 초기화 코드 브루트포스 취약 `수정 완료`

- **위치:** `backend/app/services/auth_service.py`
- **문제:** 4자리 코드 + 검증 시도 제한 없음 → 브루트포스 가능
- **수정 내용:**
  - 6자리 코드로 변경 (`secrets.randbelow(1000000):06d`)
  - 검증 시도 5회 제한 (`_MAX_RESET_ATTEMPTS = 5`), 초과 시 코드 무효화
  - `verify-reset-code`, `update-password` 엔드포인트에 rate limiting 추가 (`5/minute`)
- **잔여:** 인메모리 저장은 유지 (수평 스케일링 시 Redis 전환 필요)
- **수정일:** 2026-03-21

---

## HIGH (v2.0 릴리즈 전 수정 권장)

### H-1. JWT Secret 기본값이 약함 `수정 완료`

- **위치:** `backend/app/config.py`, `backend/app/main.py`
- **수정 내용:** lifespan에서 기본값 `"change-this-secret-in-production"` 감지 시 `RuntimeError`로 서버 시작 차단
- **수정일:** 2026-03-21

### H-2. CORS 와일드카드 기본값 `수정 완료`

- **위치:** `backend/app/config.py`, `backend/app/main.py`
- **수정 내용:**
  - `cors_origins` 기본값을 `["*"]` → `[]`(빈 리스트)로 변경
  - `.env`에서 `CORS_ORIGINS` 환경변수로 허용 오리진 설정
  - `main.py`에서 `settings.cors_origins` 참조
- **수정일:** 2026-03-21

### H-3. 로그인/회원가입 Rate Limiting 없음 `수정 완료`

- **위치:** `backend/app/routers/auth.py`
- **수정 내용:**
  - signup: `5/minute`, login: `10/minute`, oauth: `10/minute`
  - reset-password: `3/minute`, verify-reset-code: `5/minute`, update-password: `5/minute`
  - IP 기반 rate limit 키 함수 (`_get_auth_rate_limit_key`)
- **수정일:** 2026-03-21

### H-4. 비밀번호 강도 검증 없음 `수정 완료`

- **위치:** `backend/app/schemas/auth.py`
- **수정 내용:**
  - `SignUpRequest.password`, `UpdatePasswordRequest.new_password`에 `field_validator` 추가
  - 규칙: 최소 8자, 영문자 1개 이상, 숫자 1개 이상
  - 위반 시 422 Unprocessable Entity 응답
- **수정일:** 2026-03-21

### H-5. 상태관리 SSOT 부재 — 10+ 스크린이 동일 데이터 독립 fetch `수정 완료`

- **위치:** 전체 스크린이 `getActivePet()` 독립 호출 → Riverpod provider로 통일
- **영향:** 불필요한 네트워크 요청, 화면간 데이터 불일치 가능
- **수정 내용 (Phase 0-7 전체 완료):**
  - `flutter_riverpod: ^2.6.1` 도입, `ProviderScope` 래핑
  - `activePetProvider` (AsyncNotifierProvider) — 활성 펫 SSOT
  - `petListProvider`, `premiumStatusProvider`, `bhiProvider` — 핵심 상태 중앙 관리
  - 전체 스크린 `ConsumerStatefulWidget`/`ConsumerWidget` 전환 완료
  - 10개 서비스 DI 래퍼 (`service_providers.dart`)
  - 로그아웃 헬퍼 (`auth_actions.dart`) + SplashScreen provider 시딩
  - 레거시 `ActivePetNotifier` (ChangeNotifier) 파일 삭제 + 브릿지 코드 제거
- **상세:** `development_logs/2026-03-21-findings-followup-code-review.md` 참조
- **수정일:** 2026-03-21

### H-6. 테스트 커버리지 부족 `부분 수정`

- **수정 전:** 5개 테스트 파일, 53 케이스 (~14%)
- **수정 후:** 8개 테스트 파일, 169 케이스 (3.2배 증가)
- **추가된 테스트:**
  - `test/services/sync_service_test.dart` — SyncItem 직렬화 + 큐 관리 (18 케이스)
  - `test/services/weight_service_test.dart` — 로컬 캐시, 다중 기록, 평균 계산, 정렬 (20 케이스)
  - `test/models/models_serialization_test.dart` — Pet, WeightRecord, FoodRecord 등 10개 모델 (78 케이스)
- **잔여:** 위젯/통합 테스트, Provider 테스트, E2E 테스트
- **수정일:** 2026-03-21

---

## MEDIUM (점진적 개선)

### M-1. debugPrint 50+ 건 kDebugMode 미가드 `수정 완료`

- **주요 파일:** `iap_service.dart` (기존 래핑 완료), `sync_service.dart` (24건), `home_screen.dart` (13건)
- **영향:** release 빌드에서 로그 노출
- **수정 내용:**
  - `sync_service.dart`: 24건 `if (kDebugMode) { debugPrint(...) }` 래핑 + `foundation.dart` import 추가
  - `home_screen.dart`: 13건 동일 처리 + `foundation.dart` import 추가
  - `iap_service.dart`: 기존에 이미 kDebugMode 래핑 완료 확인
- **수정일:** 2026-03-20

### M-2. 하드코딩된 색상 600+ 건 `수정 완료`

- **수정 전:** screens + widgets에서 ~530건 `Color(0x...)` 하드코딩
- **수정 후:** 0건 (전체 제거)
- **AppColors 상수 추가 (colors.dart):**
  - 시맨틱: `danger`, `dangerLight`, `dangerDark`, `dangerDarker`, `dangerDeep`
  - 시맨틱: `success`, `successLight`, `successDark`, `successDarker`, `successMedium`
  - 시맨틱: `info`, `infoLight`, `infoDark`, `infoDarker`, `infoDeep`
  - 시맨틱: `warning`, `warningDark`, `warningDeep`
  - 브랜드: `brandLighter`, `brandPale`, `brandAccent`, `gradientBottomAlt`
  - 오버레이: `shadowLight`, `shadowMedium`, `overlay50`, `overlay30`, `overlayWhite60/80/90`
  - 차트: `yellow`, `yellowLight`, `lime`
  - 헬스체크: `partSpecificBlue`, `droppingsPurple`, `foodGreen`
  - 체중: `weightIdeal`, `weightWarning`, `weightLight`
  - 회색: `gray100Alt`
- **수정일:** 2026-03-20 (상위 4파일), 2026-03-21 (나머지 전체)

### M-3. fontFamily: 'Pretendard' 419건 하드코딩 `수정 완료`

- **수정 내용:**
  - `typography.dart`: `fontFamily = 'Roboto'` → `'Pretendard'`로 수정
  - `app_theme.dart`: light/dark 테마에 `fontFamily: AppTypography.fontFamily` 전역 설정 추가
  - 41개 파일에서 419건 `fontFamily: 'Pretendard'` 일괄 제거
  - 잔여: 0건
- **수정일:** 2026-03-20

### M-4. 하드코딩된 한국어 문자열 10+ 건 `수정 완료`

- **수정 내용:**
  - `add_schedule_bottom_sheet.dart`: 요일 배열, 오전/오후, 에러 메시지, 날짜 포맷, 제목 힌트, 취소/저장 버튼 → ARB 키 사용
  - `home_screen.dart`: `'사랑이'` → `l10n.common_defaultPetName`
  - `app_router.dart`: `'점점이'` → `l10n.common_defaultPetName`
- **ARB 신규 키 8개 추가** (ko/en/zh 3개 파일):
  - `datetime_am`, `datetime_pm`, `datetime_yearMonth`
  - `schedule_noPetInfo`, `schedule_noTitle`, `schedule_endTimeAfterStart`, `schedule_titleHint`
  - `common_defaultPetName`
- **수정일:** 2026-03-20

### M-5. 접근성 (Semantics) 거의 미구현 `수정 완료`

- **수정 전:** Semantics 위젯 0건, Tooltip 1건
- **수정 후:** 144개 GestureDetector 전체에 `Semantics(button: true, label: ...)` 래핑
- **수정 내용:**
  - 37개 파일 (screens 27개 + widgets 10개)의 모든 GestureDetector에 Semantics 추가
  - 텍스트 버튼: 텍스트/l10n 키를 label로 사용
  - 아이콘 버튼: 동작 설명 label ('Go back', 'Close', 'Send message' 등)
  - 체크박스: `checked:` 속성 추가 (terms_agreement_section)
  - 선택 요소: `selected:` 속성 추가 (날짜, 색상, 탭)
- **수정일:** 2026-03-21

### M-6. 서비스 싱글턴 패턴 비일관 `수정 완료`

- **수정 내용:**
  - 8개 비싱글턴 서비스를 `static final instance` 싱글턴 패턴으로 전환:
    - `FoodRecordService`, `WaterRecordService`, `DailyRecordService`
    - `AiEncyclopediaService`, `AiStreamService`, `AuthService`
    - `ScheduleService`, `NotificationService`
  - 15개 호출부 `Service()` → `Service.instance`로 수정
  - 현재: 전체 27개 서비스 모두 싱글턴 패턴 통일
- **수정일:** 2026-03-20

### ~~M-7. FCM 포그라운드 핸들러 미구현~~ `해당 없음 (의도적 설계)`

- **결론:** NotificationService polling으로 인앱 알림을 처리하고 있어 FCM 포그라운드 팝업 불필요
- **상세:** `development_logs/m7-fcm-foreground-decision.md` 참조

---

## LOW (향후 개선)

### L-1. PetLocalCacheService O(n) 업데이트 `수정 완료`

- **수정 전:** 매 호출마다 SharedPreferences 전체 읽기/쓰기
- **수정 후:** 인메모리 캐시(`_cachedPets`, `_cachedActivePetId`) 추가. 첫 호출만 SharedPreferences 접근, 이후 인메모리 즉시 반환
- **수정일:** 2026-03-22

### ~~L-2. Token 만료 사전 체크 없음~~ `해당 없음 (현재 방식 충분)`

- **결론:** 401 → 자동 갱신 → 재시도가 이미 작동. 사전 갱신의 UX 개선 효과 체감 불가 (~200ms/시간)
- **상세:** `development_logs/2026-03-22-l2-token-proactive-refresh-decision.md` 참조

### L-3. sqflite 의존성 미사용 `해당 없음 (오탐)`

- ~~pubspec.yaml에 포함되어 있으나 실제 사용 없음~~
- **확인 결과:** `local_image_storage_service.dart`에서 실제 사용 중 → 수정 불필요

### L-4. cupertino_icons 미사용 의존성 `수정 완료`

- **수정 내용:** `pubspec.yaml`에서 `cupertino_icons: ^1.0.8` 제거
- **수정일:** 2026-03-20

### ~~L-5. home_vector PNG SVG 변환~~ `해당 없음 (임팩트 낮음)`

- 앱 번들 크기 자체가 작아 ~300KB 절약 효과 미미. 제거.

### L-6. 이메일 존재 여부 노출 `수정 완료`

- **수정 전:** signup 시 409 "Email already registered" → 이메일 열거 가능
- **수정 후:** 409 "Signup failed" (일반화). 프론트엔드는 409 상태 코드로 판단하여 사용자 안내
- **수정일:** 2026-03-22

---

---

## AI 에이전트 정확도 평가 (2026-04-04)

> 대상: 챗봇(AI Encyclopedia) + 비전(Health Check) 에이전트
> 핵심 파일: `backend/app/services/ai_service.py`, `embedding_service.py`, `vector_search_service.py`, `deepseek_service.py`

---

### 챗봇 에이전트 (AI Encyclopedia)

#### P0 — 정확도 직접 영향

**CB-1. 대화 히스토리 길이 제한 없음 — 컨텍스트 오버플로우**
- **위치:** `ai_service.py:484-491` (`_ask_core`), `:546-552` (`ask_stream_with_message`)
- **문제:** 전체 `history`를 그대로 messages에 추가. 긴 대화 시 모델 컨텍스트 윈도우 초과 → 시스템 프롬프트 무시, 최근 맥락 손실, 답변 정확도 저하
- **개선안:** 최근 N턴 슬라이딩 윈도우 (예: 최근 10턴) + 오래된 대화 요약 삽입. 또는 토큰 수 기반 동적 트림 (gpt-4.1-nano 컨텍스트 한계 고려)

**CB-2. RAG 컨텍스트가 한국어 고정 — 다국어 정확도 저하**
- **위치:** `ai_service.py:272-314` (`_build_rag_context`)
- **문제:** "이름:", "종:", "최근 30일 체중(g):" 등 모든 RAG 컨텍스트가 한국어. 영어/중국어 사용자 → 모델이 한국어 컨텍스트를 해석 후 번역해야 함 → 정보 손실/혼동 발생
- **개선안:** `_build_rag_context`에 `language` 파라미터 추가, 레이블을 다국어 딕셔너리로 전환 (기존 `_HEADERS` 패턴 재활용)

**CB-3. 카테고리 분류 검증 없음 — 오분류 시 잘못된 포맷 적용**
- **위치:** `ai_service.py:42-52` (`_CATEGORY_CLASSIFICATION`)
- **문제:** "silently classify"로 지시하지만, 모델이 실제로 어떤 카테고리로 분류했는지 검증 불가. 예: 행동 질문을 질병으로 분류 → 불필요한 수의사 추천
- **개선안:** 2-pass 방식: 1차에서 카테고리만 structured output으로 받고, 2차에서 해당 카테고리 프롬프트로 답변 생성. 또는 `response_format` JSON 사용하여 카테고리를 명시적 필드로 받기

**CB-4. 지식 베이스 품질/커버리지 모니터링 없음**
- **위치:** vector_search_service.py (검색) + knowledge_chunk 모델
- **문제:** 벡터 DB에 어떤 콘텐츠가 얼마나 있는지, 어떤 주제가 부족한지 파악 불가. 지식 부재 시 모델이 자체 지식으로 답변 → 최신 정보 부정확
- **개선안:** 지식 베이스 커버리지 대시보드 + 카테고리별 chunk 수 모니터링 + 유사도 점수 로깅 (threshold 이하 쿼리 = 지식 부족 신호)

#### P1 — 정확도 간접 영향

**CB-5. Few-shot 예시 없음 — 포맷 불일치 빈발**
- **위치:** `ai_service.py:112-146` (`_PREMIUM_FORMAT_TEMPLATE`)
- **문제:** 구조화 포맷을 텍스트로만 설명. 모델이 에모지 헤더 순서, 들여쓰기, severity 표기를 일관되게 따르지 않음
- **개선안:** 각 카테고리별 1개 이상의 few-shot 예시 추가 (시스템 프롬프트 내)

**CB-6. 메타데이터 태그 파싱 취약 — silent failure**
- **위치:** `ai_service.py:184-214` (`_META_PATTERN`, `parse_response_metadata`)
- **문제:** `<!-- META:category=X|severity=Y|vet=Z -->` 형식을 정확히 따르지 않으면 (공백, 순서 변경 등) 메타데이터가 null. 클라이언트에서 severity/vet 표시 불가
- **개선안:** 정규식 유연화 + fallback 파서 (LLM에게 재질문) 또는 structured output 사용

**CB-7. 언어 감지 단순 — 혼합 언어 오탐**
- **위치:** `ai_service.py:368-379` (`_detect_language`)
- **문제:** 문자 범위 체크만 사용. "앵무새 feather plucking 치료" → Korean 감지 (맞음), 하지만 "我的budgie有问题" → Chinese 감지 (영어 단어 무시). 일본어 히라가나/카타카나 미지원
- **개선안:** 빈도 기반 감지 (가장 많은 문자 세트) 또는 langdetect 라이브러리 사용

**CB-8. 대화 요약 없음 — 장기 대화 품질 저하**
- **문제:** CB-1과 연관. 오래된 대화 컨텍스트를 요약하는 메커니즘이 없어, 짧은 윈도우만 사용하면 이전 대화 맥락 손실
- **개선안:** 일정 턴 수 초과 시 이전 대화를 LLM으로 요약하여 시스템 메시지에 삽입

#### P2 — 개선 시 정확도 향상

**CB-9. 벡터 검색 Re-ranking 없음**
- 현재: 코사인 유사도 raw score로 top-k 반환. Cross-encoder reranker 추가 시 검색 정밀도 향상

**CB-10. 종별 특화 정보 부족**
- 앵무새 종별로 정상 범위가 다름 (예: 잉꼬 vs 대형앵무 체중/사료량). 프롬프트에 종별 정상 범위 참조 지시 없음

**CB-11. 모델 선택 최적화 여지**
- 현재 `gpt-4.1-nano` 사용. 질병/응급 카테고리는 더 큰 모델 (gpt-4o-mini 이상) 사용 시 의학적 정확도 향상 가능

---

### 비전 에이전트 (Health Check)

#### P0 — 정확도 직접 영향

**VIS-1. 이미지 품질 사전 검증 없음 — 저품질 이미지에서 과신 분석**
- **위치:** `ai_service.py:822-933` (`analyze_vision_health_check`)
- **문제:** 흐릿한/어두운/원거리 이미지도 그대로 GPT-4o에 전달 → 모델이 보이지 않는 부분을 추론(환각)하여 높은 confidence로 반환
- **개선안:** 이미지 전처리 단계 추가 — 1) 밝기/선명도 검사 2) 조류 객체 탐지 (이미지에 새가 있는지) 3) 최소 해상도 검증. 또는 비전 모델에게 먼저 "이미지 품질 평가" 요청 후 threshold 미달 시 재촬영 안내

**VIS-2. full_body 모드: 보이지 않는 부위도 필수 평가 — 환각 유발**
- **위치:** `ai_service.py:623-624`
- **문제:** "Include ALL 6 standard areas in findings even if they appear normal" → 발이 안 보이는 사진에서도 foot을 "normal"로 평가. 이것은 거짓 음성(false negative)
- **개선안:** 프롬프트 수정: "If an area is NOT clearly visible in the image, set severity to 'not_visible' and observation to 'This area is not visible in the provided image. Please take a closer photo.'" + 클라이언트에서 not_visible 상태 처리

**VIS-3. Confidence score 미보정 — 과대 추정**
- **위치:** `ai_service.py:618` (confidence_score 0-100)
- **문제:** GPT-4o의 자체 보고 confidence는 실제 정확도와 상관관계가 낮음. 85점이라고 해도 실제 정확도는 60% 수준일 수 있음
- **개선안:** 1) 수의사 검증 데이터셋으로 confidence 보정 곡선 구축 2) confidence를 범위로 표시 (예: "중간 확신도") 3) "not_visible" 영역 수에 따라 전체 confidence 감소 적용

**VIS-4. 종별 정상 범위 미참조 — 오진 위험**
- **위치:** Vision 프롬프트 전체
- **문제:** 코카틸의 정상 깃털 패턴과 아마존 앵무의 정상 패턴이 다름. 프롬프트에 "Consider species-specific norms" 지시 없음. 펫 프로필의 종 정보가 RAG에 포함되지만, 비전 프롬프트에서 종별 차이를 명시적으로 요구하지 않음
- **개선안:** 비전 프롬프트에 종별 참조 블록 추가: "The parrot's species is {species}. Consider species-specific normal ranges for body condition, feather patterns, beak shape, and foot structure."

**VIS-5. 단일 이미지 분석 — 제한된 진단 정보**
- **위치:** `ai_service.py:882-889` (단일 image_url)
- **문제:** 한 장의 사진으로 6개 부위를 모두 평가. 정면 사진에서는 등/꼬리/발바닥 보이지 않음
- **개선안:** 멀티 이미지 지원 (정면 + 측면 + 위에서) 또는 촬영 가이드 표시 후 모드별 권장 각도 안내

#### P1 — 정확도 간접 영향

**VIS-6. 음식 독성 목록 불완전**
- **위치:** `ai_service.py:692`
- **문제:** avocado, chocolate, caffeine, onion, garlic, alcohol만 명시. 누락: apple seeds, cherry/peach pits, mushrooms, raw beans, rhubarb, tomato leaves, xylitol, high-salt/high-fat foods
- **개선안:** 포괄적 독성 목록 + severity 등급 포함. 또는 지식 베이스에 독성 식품 데이터베이스 적재

**VIS-7. 배변 분석: 종별/식이별 정상 범위 미제공**
- **위치:** `ai_service.py:661-685` (`_VISION_DROPPINGS_PROMPT`)
- **문제:** "Check color, texture, ratio, and abnormalities"만 지시. 씨앗 식이 vs 펠릿 식이에 따라 배변 색/질감이 다름. 과일 많이 먹은 날은 수분 증가 → 오진 가능
- **개선안:** RAG 컨텍스트에서 최근 식이 데이터를 비전 프롬프트에 명시적 연결: "Recent diet: {food_data}. Consider diet-related variations in droppings appearance."

**VIS-8. JSON 파싱 실패 시 재시도 없음**
- **위치:** `ai_service.py:906-917`
- **문제:** JSON 파싱 실패 → confidence 0 + 빈 findings 반환. 사용자는 "분석 실패" 경험
- **개선안:** 1회 재시도 (temperature 약간 낮춰서) + 마크다운 응답에서 JSON 추출 시도

**VIS-9. 이전 분석과 비교 불가 — 변화 추적 불가**
- **문제:** 각 분석이 독립적. "지난주 대비 깃털 상태 변화" 같은 시계열 비교 불가
- **개선안:** 이전 분석 결과를 RAG 컨텍스트에 포함 (최근 3회 분석 결과 요약)

#### P2 — 개선 시 정확도 향상

**VIS-10. part_specific 부위 부족**
- 현재 4부위 (eye, beak, feather, foot). 누락: wing, tail, vent/cloaca, crop, nares(콧구멍)

**VIS-11. severity 기준 모드간 불일치**
- full_body의 "warning"과 droppings의 "warning"이 임상적으로 다른 의미일 수 있으나 동일 UI 표시

**VIS-12. 잘못된 status 기본값**
- **위치:** `ai_service.py:929-931`
- 유효하지 않은 status → "caution"으로 기본 대체. 모델 혼란을 감추어 디버깅 어려움

---

### 우선순위 요약

| 등급 | ID | 에이전트 | 핵심 이슈 | 정확도 영향 |
|------|-----|----------|-----------|------------|
| P0 | CB-1 | 챗봇 | 히스토리 길이 무제한 | 긴 대화 시 답변 품질 급락 |
| P0 | CB-2 | 챗봇 | RAG 한국어 고정 | 영어/중국어 사용자 정확도 저하 |
| P0 | CB-3 | 챗봇 | 카테고리 무검증 | 오분류 → 잘못된 포맷/추천 |
| P0 | CB-4 | 챗봇 | 지식 베이스 모니터링 없음 | 부족한 영역 파악 불가 |
| P0 | VIS-1 | 비전 | 이미지 품질 미검증 | 저품질→환각 분석 |
| P0 | VIS-2 | 비전 | 안 보이는 부위 필수 평가 | 거짓 음성 (false negative) |
| P0 | VIS-3 | 비전 | Confidence 미보정 | 사용자 오신뢰 |
| P0 | VIS-4 | 비전 | 종별 정상 범위 미참조 | 종 차이 무시한 오진 |
| P0 | VIS-5 | 비전 | 단일 이미지 한계 | 진단 정보 부족 |
| P1 | CB-5 | 챗봇 | Few-shot 없음 | 포맷 불일치 |
| P1 | CB-6 | 챗봇 | 메타데이터 파싱 취약 | 심각도 누락 |
| P1 | CB-7 | 챗봇 | 언어 감지 단순 | 혼합 언어 오탐 |
| P1 | CB-8 | 챗봇 | 대화 요약 없음 | 장기 대화 맥락 손실 |
| P1 | VIS-6 | 비전 | 독성 목록 불완전 | 위험 식품 미감지 |
| P1 | VIS-7 | 비전 | 배변 종별/식이 기준 없음 | 정상 변이를 이상으로 오진 |
| P1 | VIS-8 | 비전 | JSON 실패 시 무재시도 | 분석 완전 실패 |
| P1 | VIS-9 | 비전 | 이전 분석 비교 불가 | 시계열 변화 감지 불가 |

### 수정 현황 (2026-04-04)

| 상태 | 항목 수 | 목록 |
|------|---------|------|
| 수정 완료 | 23건 | CB-1~11, VIS-1~12 전체 |
| 상세 | — | `development_logs/2026-04-04-ai-agent-accuracy-improvements.md` 참조 |

---

## 수정 현황 요약

> 최종 업데이트: 2026-03-21 (Riverpod Phase 0-5 반영)

| 상태 | 항목 수 | 목록 |
|------|---------|------|
| 수정 완료 | 16건 | C-1, C-2, H-1, H-2, H-3, H-4, M-1, M-2, M-3, M-4, M-5, M-6, L-1, L-4, L-6 |
| 수정 완료 (Riverpod) | 1건 | H-5 (Phase 0-7 전체 완료) |
| 부분 수정 | 1건 | H-6 (53 → 169 케이스, 핵심 서비스+모델 커버) |
| 미수정 (Flutter 대규모) | 0건 | — |
| 미수정 | 0건 | — |
| 해당 없음 (현재 방식 충분) | 1건 | L-2 (Token 사전 갱신 불필요) |
| 해당 없음 (의도적) | 1건 | M-7 (FCM 포그라운드 — polling 대체) |
| 해당 없음 (오탐) | 1건 | L-3 |

### 검증 결과

- `flutter analyze`: 0 errors (37 warnings/info — 모두 기존)
- `flutter test`: 53/53 passed
- `ActivePetNotifier.instance` in screens: 0건
- `fontFamily: 'Pretendard'` 잔여: 0건
- 상위 3파일 `Color(0x...)` 잔여: 0건

---

## Riverpod 마이그레이션 현황

> 상세 구현 기록: `development_logs/2026-03-21-findings-followup-code-review.md`

### 전체 완료 (Phase 0-7)

| Phase | 내용 | 상태 |
|-------|------|------|
| 0 | flutter_riverpod 추가 + ProviderScope | 완료 |
| 1 | activePetProvider SSOT + 14개 스크린 전환 | 완료 |
| 2 | premiumStatusProvider + bhiProvider | 완료 |
| 3 | 10개 서비스 DI 래퍼 (service_providers.dart) | 완료 |
| 4 | 로그아웃 헬퍼 (auth_actions.dart) | 완료 |
| 5 | SplashScreen provider 시딩 | 완료 |
| 6 | 나머지 20개 스크린 ConsumerStatefulWidget 전환 | 완료 |
| 7 | 레거시 ActivePetNotifier 삭제 + 브릿지 코드 제거 | 완료 |

### 달성 효과

- SSOT 확보 → 전체 스크린에서 독립 `getActivePet()` 제거
- 펫 전환 시 `ref.watch` 체인으로 전체 화면 자동 갱신
- `ref.invalidate()`로 캐시 무효화 통일
- `ProviderScope(overrides: [...])` 테스트 모킹 가능
- 레거시 ChangeNotifier 완전 삭제 (메모리 누수 위험 제거)

---

## 프로젝트 건강 점수 요약

| 영역           | 수정 전 | 수정 후    | 핵심 이슈                                      |
| -------------- | ------- | ---------- | ---------------------------------------------- |
| 에러 핸들링    | 9/10    | 9/10       | 컨텍스트별 로컬라이즈, 우수                    |
| API 클라이언트 | 9/10    | 9/10       | 토큰 갱신, 타임아웃, 보안 저장소               |
| 오프라인 싱크  | 8/10    | 8/10       | 스마트한 설계, 일부 엣지케이스                 |
| i18n           | 9/10    | **9.5/10** | 3언어 117키 동기화, 하드코딩 0건 (수정)        |
| 테마           | 7/10    | **9.5/10** | fontFamily 전역화, 하드코딩 색상 전체 제거    |
| 네비게이션     | 9/10    | 9/10       | go_router 인증 가드, 구조 우수                 |
| 상태관리       | 5/10    | **8.5/10** | Riverpod SSOT 완료, 전체 스크린 전환, 레거시 삭제 |
| 테스트         | 3/10    | **5.5/10** | 8개 파일 169 케이스, 핵심 서비스+모델 커버     |
| 접근성         | 2/10    | **6.5/10** | 144개 GestureDetector Semantics 래핑 완료      |
| 백엔드 보안    | 5/10    | **8/10**   | IDOR 수정, rate limiting, 비밀번호 정책 추가   |
| 플랫폼 통합    | 7/10    | **7.5/10** | debugPrint 가드 완료 (수정), FCM 미완          |

**종합: 6.6/10 → 8.2/10** (코드 리뷰 수정 + Riverpod SSOT + 테스트 확대 + 색상 정리 + 접근성 반영)

