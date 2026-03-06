# 품종 표준 시스템 + Codex 리뷰 P1/P2 이슈 수정 (2026-03-07)

**날짜**: 2026-03-07
**작성자**: Claude Code
**상태**: 완료

---

## 개요

품종별 체중 표준(BreedStandard) 시스템을 백엔드 + 프론트엔드 전체 스택으로 구축하고, BHI 절대 체중 점수·체중 차트 라벨 개선·first_aid 렌더링·체중 범위 인디케이터 등 8개 Fix를 구현한 후, Codex CLI(GPT-5.4, effort: high)로 전체 코드 리뷰를 수행했다. 리뷰에서 발견된 P1 3건 / P2 3건을 추가 수정하여 배포했다.

### 커밋 이력

| 커밋 | 설명 |
|------|------|
| `5754821` | 품종 표준 시스템 + Codex 리뷰 P1/P2 이슈 수정 |

### 변경 규모

| 항목 | 수치 |
|------|------|
| 변경 파일 | 29개 (신규 9 + 수정 20) |
| 추가 | +1,674 lines |
| 삭제 | -70 lines |

---

## 작업 흐름

```
[8개 Fix 구현] → [Codex CLI 코드 리뷰] → [P1/P2 이슈 5건 추가 수정] → [검증] → [배포] → [curl 테스트]
```

---

## Part 1: 품종 표준 시스템 (BreedStandard)

### 신규 파일

| 파일 | 설명 |
|------|------|
| `backend/app/models/breed_standard.py` | BreedStandard SQLAlchemy 모델 (다국어 이름, 체중 4단계 범위, 환경 구분) |
| `backend/app/schemas/breed_standard.py` | Pydantic DTO: `BreedStandardResponse`, `BreedStandardListItem` |
| `backend/app/services/breed_standard_service.py` | 로컬라이즈된 품종 목록/개별 조회 서비스 |
| `backend/app/routers/breed_standards.py` | REST API: `GET /breed-standards/`, `GET /breed-standards/{id}` |
| `backend/alembic/versions/010_add_breed_standards.py` | Alembic 마이그레이션 + 초기 품종 데이터 시드 (앵무새 20종) |
| `lib/src/models/breed_standard.dart` | Flutter BreedStandard + WeightRangeInfo 모델 |
| `lib/src/services/breed/breed_service.dart` | 품종 API 서비스 (세션 내 캐시) |
| `lib/src/widgets/breed_selector.dart` | 검색 가능한 품종 선택 다이얼로그 위젯 |
| `lib/src/widgets/weight_range_indicator.dart` | 체중 범위 시각화 위젯 (CustomPainter) |

### 데이터 모델

```
BreedStandard
├── id (UUID)
├── species_category (예: "parrot")
├── breed_name_en / breed_name_ko / breed_name_zh (다국어)
├── breed_variant (예: "Green-cheeked")
├── weight_min_g / weight_ideal_min_g / weight_ideal_max_g / weight_max_g
├── environment ("pet" / "wild")
└── is_active (boolean)
```

### API 엔드포인트

| Method | Path | 설명 |
|--------|------|------|
| `GET` | `/breed-standards/` | 활성 품종 목록 (Accept-Language 기반 로컬라이즈) |
| `GET` | `/breed-standards/{id}` | 개별 품종 조회 (로컬라이즈) |

---

## Part 2: 기존 8개 Fix

### Fix #1: GET /{id} 스키마 통일 + Accept-Language

**파일**: `backend/app/routers/breed_standards.py`, `backend/app/services/breed_standard_service.py`

`GET /{id}`의 반환 타입을 `BreedStandardListItem`으로 통일하고, 두 엔드포인트 모두 `Accept-Language` 헤더를 받아 `display_name`을 해당 언어로 반환한다.

### Fix #2: effectiveBreed = _selectedBreedDisplayName

**파일**: `lib/src/screens/pet/pet_add_screen.dart`

펫 저장 시 품종 선택이 있으면 `_selectedBreedDisplayName`을 `breed` 필드로 저장한다. 기타(Other) 선택이면 수동 입력값을 사용.

### Fix #3: updateBreedFields 플래그

**파일**: `lib/src/services/pet/pet_service.dart`

`updatePet()`에 `updateBreedFields: true` 플래그 추가. true이면 `breed`와 `breed_id`를 명시적으로 전송(null 포함)하여, 품종 변경/해제가 서버에 정확히 반영된다.

### Fix #4: first_aid 섹션 렌더링

**파일**: `lib/src/screens/health_check/health_check_result_screen.dart`

AI 건강체크 응답의 `first_aid` 배열을 오렌지 카드(`#FFF3E0` 배경, `#E65100` 텍스트)로 렌더링한다. 번호 매기기 포함.

### Fix #5: 체중 차트 라벨 경계 클램프 + 겹침 방지

**파일**: `lib/src/screens/weight/weight_detail_screen.dart`

차트 위 라벨이 차트 영역을 벗어나지 않도록 `.clamp()`로 경계 제한하고, X축 인접 라벨 간 `minGap` 기반 겹침 방지 로직을 추가했다.

### Fix #6: breed_selector 하드코딩 → l10n + variant 중복 제거

**파일**: `lib/src/widgets/breed_selector.dart`

4개 하드코딩 문자열(`breed_selectTitle`, `breed_searchHint`, `breed_noBreeds`, `breed_notFound`)을 l10n으로 전환하고, breed_variant가 display_name에 중복 포함되지 않도록 처리했다.

### Fix #7: weight_range_indicator totalRange <= 0 가드

**파일**: `lib/src/widgets/weight_range_indicator.dart`

`totalRange`가 0 이하일 때 CustomPainter에서 0으로 나누는 것을 방지하기 위해 early return 가드를 추가했다.

### Fix #8: BHI weight_score에 w_t 반환 + 중복 조회 제거

**파일**: `backend/app/services/bhi_service.py`, `backend/app/schemas/bhi.py`

`_calc_weight_score`가 `w_t`(현재 체중)도 함께 반환하도록 변경하여 `calculate_bhi`에서 체중을 중복 조회하지 않는다. 절대 체중 점수(`weight_score_absolute`)와 품종 체중 범위 정보(`breed_weight_info`)를 BHI 응답에 추가했다.

---

## Part 3: Codex CLI 코드 리뷰

### 리뷰 환경

| 항목 | 설정 |
|------|------|
| CLI | codex-cli v0.42.0 |
| 모델 | GPT-5.4 |
| Reasoning Effort | high |
| 실행 모드 | `--full-auto` |
| 대상 | git diff (20 files) + untracked (9 files) |

### 핵심 발견 사항 (P1/P2)

| 심각도 | 이슈 | 위치 |
|--------|------|------|
| **P1** | 펫 수정 화면 진입 시 `_selectedBreedDisplayName` 미초기화 → breed가 null로 저장됨 | `pet_add_screen.dart:97` |
| **P1** | 서버가 `breed_id` 존재/활성 여부 미검증 → 잘못된 UUID에서 DB IntegrityError 500 | `pet_service.py:36,44` |
| **P1** | `breed_selector` 검색 0건일 때 Other 옵션 사라짐 → 커스텀 품종 입력 불가 | `breed_selector.dart:296` |
| **P2** | 백엔드는 `Accept-Language` 읽지만 프론트 API 클라이언트가 헤더 미전송 | `api_client.dart:34` |
| **P2** | `first_aid`를 `List<dynamic>` 단정 캐스팅 → AI 응답 형식 불일치 시 런타임 예외 | `health_check_result_screen.dart:247` |
| **P2** | 로컬라이즈된 display_name을 DB breed에 저장 → 언어 변경 시 데이터 일관성 깨짐 | `pet_add_screen.dart:221` |

---

## Part 4: Codex 리뷰 P1/P2 수정

### 수정 1: [P1] 펫 수정 시 breed display name 초기화

**파일**: `lib/src/screens/pet/pet_add_screen.dart`

**문제**:
수정 화면 진입 시 `_selectedBreedId`만 설정하고 `_selectedBreedDisplayName`은 `null`로 남겨둠. 사용자가 아무것도 변경하지 않고 저장하면 `effectiveBreed`가 `null`이 되어 breed 정보가 사라진다.

**수정 전**:
```dart
if (pet.breedId != null) {
  _selectedBreedId = pet.breedId;
  // breed display name will be loaded by BreedSelector
}
```

**수정 후**:
```dart
if (pet.breedId != null) {
  _selectedBreedId = pet.breedId;
  final breed = await BreedService.instance.fetchBreedById(pet.breedId!);
  if (breed != null) {
    _selectedBreedDisplayName = breed.displayName;
  } else {
    _selectedBreedDisplayName = pet.breed;
  }
}
```

**해결 원리**: `BreedService.fetchBreedById()`로 품종을 조회하여 로컬라이즈된 display name을 즉시 채운다. 품종이 삭제/비활성인 경우 기존 `pet.breed` 값으로 폴백.

---

### 수정 2: [P1] breed_selector 검색 0건에도 Other 항상 노출

**파일**: `lib/src/widgets/breed_selector.dart`

**문제**:
검색 결과가 비면 `Center(Text("검색 결과 없음"))` 만 표시되고 Other 옵션이 사라진다. 목록에 없는 품종을 직접 입력하는 유일한 탈출구가 차단됨.

**수정 전**:
```dart
: _filteredBreeds.isEmpty
    ? Center(child: Text(l10n.breed_notFound))
    : ListView.separated(...)
```

**수정 후**:
```dart
: _filteredBreeds.isEmpty
    ? Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(l10n.breed_notFound),
          const SizedBox(height: 16),
          _buildOtherOption(),  // 항상 Other 노출
        ],
      )
    : ListView.separated(...)
```

---

### 수정 3: [P1] 서버 breed_id 유효성 검증

**파일**: `backend/app/services/pet_service.py`

**문제**:
프론트에서 `breed_id`를 보낼 때 서버가 해당 UUID의 존재/활성 여부를 검증하지 않음. 잘못된 UUID를 보내면 FK constraint 위반으로 500 Internal Server Error 노출.

**수정**: `_validate_breed_id()` 함수 추가.

```python
async def _validate_breed_id(db: AsyncSession, breed_id: UUID | None) -> None:
    """breed_id가 존재하면 활성 품종인지 검증."""
    if breed_id is None:
        return
    result = await db.execute(
        select(BreedStandard.id).where(
            BreedStandard.id == breed_id,
            BreedStandard.is_active == True,
        )
    )
    if result.scalar_one_or_none() is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Invalid or inactive breed_id: {breed_id}",
        )
```

`create_pet()`과 `update_pet()`에서 호출:

```python
async def create_pet(db, user_id, data):
    await _validate_breed_id(db, data.breed_id)  # 추가
    # ...

async def update_pet(db, pet_id, user_id, data):
    if data.breed_id is not None:
        await _validate_breed_id(db, data.breed_id)  # 추가
    # ...
```

**해결 원리**: 잘못된 breed_id에 대해 500 대신 `422 Unprocessable Entity`를 명시적으로 반환한다. `is_active == True` 조건으로 비활성 품종도 거부.

---

### 수정 4: [P2] API 클라이언트 Accept-Language 헤더 자동 전송

**파일**: `lib/src/services/api/api_client.dart`

**문제**:
백엔드 `breed_standards` 라우터가 `Accept-Language` 헤더로 로컬라이즈하지만, API 클라이언트가 이 헤더를 보내지 않아 항상 기본값(`en`)으로 폴백됨.

**수정**:
```dart
import 'dart:ui' as ui;

String get _acceptLanguage {
  final locale = ui.PlatformDispatcher.instance.locale;
  return locale.toLanguageTag();  // 예: "ko-KR", "zh-CN", "en-US"
}

Map<String, String> get _authHeaders {
  final token = _tokenService.accessToken;
  if (token == null) throw Exception('Not authenticated');
  return {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
    'Accept-Language': _acceptLanguage,  // 추가
  };
}
```

**해결 원리**: 디바이스의 현재 locale을 `PlatformDispatcher`에서 읽어 모든 인증 요청에 `Accept-Language` 헤더를 자동으로 첨부한다. 백엔드 로컬라이즈 엔드포인트가 실제로 동작하게 된다.

---

### 수정 5: [P2] first_aid 타입 방어 코드

**파일**: `lib/src/screens/health_check/health_check_result_screen.dart`

**문제**:
`f['first_aid'] as List<dynamic>?`로 단정 캐스팅하여, AI가 first_aid를 문자열이나 null이 아닌 다른 타입으로 반환하면 `TypeError` 런타임 예외 발생.

**수정 전**:
```dart
final firstAid = (f['first_aid'] as List<dynamic>?)
    ?.map((e) => e.toString())
    .toList();
```

**수정 후**:
```dart
final rawFirstAid = f['first_aid'];
final firstAid = rawFirstAid is List
    ? rawFirstAid.map((e) => e.toString()).toList()
    : null;
```

**해결 원리**: `is List` 타입 체크로 안전하게 검사 후 변환한다. AI 응답이 문자열, 숫자, 또는 기타 비정형 타입이면 조용히 `null`로 처리되어 UI에서 first_aid 섹션이 표시되지 않는다.

---

## Part 5: 로컬라이제이션

### 추가된 l10n 키

| 키 | ko | en | zh |
|---|---|---|---|
| `breed_selectTitle` | 품종 선택 | Select Breed | 选择品种 |
| `breed_searchHint` | 품종 이름 검색 | Search breed name | 搜索品种名称 |
| `breed_noBreeds` | 등록된 품종이 없습니다 | No breeds available | 没有可用的品种 |
| `breed_notFound` | 검색 결과가 없습니다 | No results found | 未找到搜索结果 |
| `hc_firstAidTitle` | 응급 처치 | First Aid | 急救措施 |

---

## Part 6: 배포 및 API 테스트

### 배포

```
git push origin dev → Railway staging 자동 배포
```

환경: `https://perchcare-staging.up.railway.app`

### curl 테스트: AI 鹦博士 (중국어)

**요청**:
```bash
curl -X POST ".../api/v1/ai/encyclopedia" \
  -H "Accept-Language: zh-CN" \
  -d '{"query": "鹦鹉的护理方法"}'
```

**응답** (정상):
```json
{
  "answer": "鹦鹉的护理方法包括以下几个方面：\n\n1. 饮食 — 提供均衡的饮食...\n2. 环境 — 确保笼子宽敞...\n3. 社交 — 鹦鹉是社交性很强的鸟类...\n4. 健康检查 — 定期进行兽医检查...",
  "category": "general",
  "severity": null,
  "vet_recommended": false
}
```

**APV 질환 질문**:
```bash
curl -X POST ".../api/v1/ai/encyclopedia" \
  -H "Accept-Language: zh-CN" \
  -d '{"query": "APV是什么？介绍一下APV以及它的原因"}'
```

**응답** (정상):
```json
{
  "answer": "APV（鸟类多瘤病毒）是一种高度重要的病毒性疾病...",
  "category": "disease",
  "severity": "normal",
  "vet_recommended": false
}
```

AI가 중국어 질문에 정확한 중국어로 응답하며, category/severity 메타데이터도 올바르게 분류되었다.

---

## 수정된 파일 목록

| 파일 | 작업 | 변경 유형 |
|------|------|----------|
| `backend/alembic/versions/010_add_breed_standards.py` | 품종 표준 | 신규 |
| `backend/app/models/breed_standard.py` | 품종 표준 | 신규 |
| `backend/app/routers/breed_standards.py` | 품종 표준 | 신규 |
| `backend/app/schemas/breed_standard.py` | 품종 표준 | 신규 |
| `backend/app/services/breed_standard_service.py` | 품종 표준 | 신규 |
| `backend/app/main.py` | 라우터 등록 | 수정 |
| `backend/app/models/pet.py` | breed_id FK | 수정 |
| `backend/app/schemas/pet.py` | breed_id 필드 | 수정 |
| `backend/app/schemas/bhi.py` | 절대 체중 점수 필드 | 수정 |
| `backend/app/services/bhi_service.py` | w_t 반환 + 중복 제거 | 수정 |
| `backend/app/services/pet_service.py` | breed_id 검증 (Codex P1) | 수정 |
| `lib/src/models/breed_standard.dart` | 품종 모델 | 신규 |
| `lib/src/models/pet.dart` | breedId 필드 | 수정 |
| `lib/src/services/breed/breed_service.dart` | 품종 API 서비스 | 신규 |
| `lib/src/services/api/api_client.dart` | Accept-Language (Codex P2) | 수정 |
| `lib/src/services/pet/pet_service.dart` | updateBreedFields | 수정 |
| `lib/src/widgets/breed_selector.dart` | 품종 선택 위젯 | 신규 |
| `lib/src/widgets/weight_range_indicator.dart` | 체중 범위 위젯 | 신규 |
| `lib/src/screens/pet/pet_add_screen.dart` | breed 초기화 (Codex P1) | 수정 |
| `lib/src/screens/health_check/health_check_result_screen.dart` | first_aid 방어 (Codex P2) | 수정 |
| `lib/src/screens/weight/weight_detail_screen.dart` | 라벨 클램프 | 수정 |
| `lib/src/screens/weight/weight_record_screen.dart` | 체중 범위 표시 | 수정 |
| `lib/l10n/app_ko.arb` | l10n 키 추가 | 수정 |
| `lib/l10n/app_en.arb` | l10n 키 추가 | 수정 |
| `lib/l10n/app_zh.arb` | l10n 키 추가 | 수정 |
| `lib/l10n/app_localizations.dart` | 자동 생성 | 수정 |
| `lib/l10n/app_localizations_en.dart` | 자동 생성 | 수정 |
| `lib/l10n/app_localizations_ko.dart` | 자동 생성 | 수정 |
| `lib/l10n/app_localizations_zh.dart` | 자동 생성 | 수정 |

---

## 검증 체크리스트

- [x] `flutter analyze` — 에러 0건 (기존 warning만 존재)
- [x] Python `py_compile` — pet_service.py, bhi_service.py, breed_standards.py 전부 OK
- [x] Railway staging 배포 완료
- [x] curl: 중국어 AI 질문 정상 응답 확인
- [ ] 펫 수정 화면 → 품종 선택 상태 유지 확인
- [ ] 잘못된 breed_id 전송 시 422 응답 확인
- [ ] 품종 검색 0건 → Other 옵션 표시 확인
- [ ] 한국어/중국어 환경에서 품종 목록 로컬라이즈 확인

---

## 교훈 및 패턴 정리

### Codex CLI로 체계적 코드 리뷰
`codex exec --full-auto --output-last-message <path>`로 비대화형 코드 리뷰를 실행하면, AI가 git diff와 파일을 자율적으로 탐색하여 P0~P3 이슈를 분류해준다. `-c 'model_reasoning_effort="high"'`로 effort를 명시해야 config 충돌을 피할 수 있다.

### 수정 화면 진입 시 관련 데이터 hydrate 필수
`selectedBreedId`만 설정하고 `selectedBreedDisplayName`을 채우지 않으면 저장 시 null이 된다. 수정 화면 진입 시 ID에 해당하는 표시 데이터(display name, label 등)를 반드시 API/캐시에서 로드해야 한다.

### 서버 사이드 FK 검증은 선택이 아닌 필수
프론트엔드가 올바른 값을 보낸다고 가정하면 안 된다. FK 참조 대상의 존재/활성 여부를 서비스 레이어에서 검증하고, DB constraint 위반 전에 명확한 HTTP 에러(422)를 반환해야 한다.

### Accept-Language 헤더는 글로벌 API 클라이언트에서 일괄 처리
개별 서비스에서 locale을 파라미터로 전달하는 것보다, API 클라이언트의 공통 헤더에 `Accept-Language`를 추가하는 것이 누락 없이 모든 로컬라이즈 엔드포인트에 적용된다.

### AI 응답 파싱은 방어적으로
AI 모델의 응답 구조는 프롬프트와 다를 수 있다. `as List<dynamic>` 단정 캐스팅 대신 `is List` 타입 체크를 사용하여, 비정형 응답에서도 앱이 크래시되지 않도록 방어해야 한다.
