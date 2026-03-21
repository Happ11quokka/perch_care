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

### L-2. Token 만료 사전 체크 없음 `미수정`

- 현재 401 응답 후 갱신 (reactive), 만료 전 갱신 (proactive) 미구현

### L-3. sqflite 의존성 미사용 `해당 없음 (오탐)`

- ~~pubspec.yaml에 포함되어 있으나 실제 사용 없음~~
- **확인 결과:** `local_image_storage_service.dart`에서 실제 사용 중 → 수정 불필요

### L-4. cupertino_icons 미사용 의존성 `수정 완료`

- **수정 내용:** `pubspec.yaml`에서 `cupertino_icons: ^1.0.8` 제거
- **수정일:** 2026-03-20

### L-5. home_vector PNG (70-82KB each) SVG 변환 가능 `미수정`

- lv1~lv5.png → SVG로 변환 시 번들 크기 ~300KB 절약 가능

### L-6. 이메일 존재 여부 노출 `수정 완료`

- **수정 전:** signup 시 409 "Email already registered" → 이메일 열거 가능
- **수정 후:** 409 "Signup failed" (일반화). 프론트엔드는 409 상태 코드로 판단하여 사용자 안내
- **수정일:** 2026-03-22

---

## 수정 현황 요약

> 최종 업데이트: 2026-03-21 (Riverpod Phase 0-5 반영)

| 상태 | 항목 수 | 목록 |
|------|---------|------|
| 수정 완료 | 16건 | C-1, C-2, H-1, H-2, H-3, H-4, M-1, M-2, M-3, M-4, M-5, M-6, L-1, L-4, L-6 |
| 수정 완료 (Riverpod) | 1건 | H-5 (Phase 0-7 전체 완료) |
| 부분 수정 | 1건 | H-6 (53 → 169 케이스, 핵심 서비스+모델 커버) |
| 미수정 (Flutter 대규모) | 0건 | — |
| 미수정 (LOW) | 2건 | L-2, L-5 |
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

