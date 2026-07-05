# Stage 0+1 — 펫 전환 버그 수정 · 프리미엄/SNS 이벤트 제거 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 기록 탭의 펫 전환 원복 버그를 수정하고, 앱(Flutter)·백엔드(FastAPI)에서 프리미엄/IAP/쿼터 UI/SNS 이벤트 시스템을 제거한다 — 서버 쿼터는 LLM 비용 안전장치로 유지.

**Architecture:** Stage 0은 기록 탭 펫 선택기를 `ActivePetViewModel.switchPet()`(Riverpod SSOT) 경유로 교체해 provider↔로컬 상태 이중 쓰기를 단방향으로 정리한다. Stage 1은 "참조 제거 → 파일 삭제 → l10n/의존성 정리" 순서로 진행하며, 매 태스크 완료 시점에 프로젝트가 컴파일 가능해야 한다. 서버 쿼터(백과사전 월 30회 429, 비전 월 10회 403)는 유지되므로 클라이언트는 사전 차단 UI 없이 429/403 수신 시 중립 안내만 표시한다.

**Tech Stack:** Flutter + flutter_riverpod 2.6 (AsyncNotifier MVVM), go_router, flutter gen-l10n (arb ko/en/zh), FastAPI + PostgreSQL + pytest (backend/)

**Spec:** `docs/superpowers/specs/2026-07-05-premium-removal-mvvm-completion-design.md`

## Global Constraints

- **서버 쿼터 유지**: 백과사전 월 30회(429)·비전 월 10회(403) 강제는 백엔드에 남긴다. 클라이언트는 429/403 수신 시 중립 안내만 — 사전 차단 UI(잠금 카드·배지·프로모 유도)는 전부 제거.
- **신설 중립 l10n 키 (정확히 이 이름·문자열)**: `quota_limitReachedTitle` = ko "사용 한도 도달" / en "Limit Reached" / zh "已达使用上限", `quota_limitReachedMessage` = ko "이번 달 사용 한도에 도달했어요. 다음 달에 다시 이용할 수 있어요." / en "You've reached this month's usage limit. It resets next month." / zh "本月使用次数已达上限，下月将重置。"
- **DB 테이블 보존**: user_tier·premium_code 테이블 drop 마이그레이션을 만들지 않는다. 참조가 사라진 모델 파일만 삭제.
- **Railway 환경변수 불변경**: 환경변수 변경은 자동 재배포를 트리거한다 — 모든 처리는 코드로만.
- **docs/marketing/ 샤오홍슈 캠페인 문서 유지** (사용자 결정). 개인정보처리방침의 일반 "이벤트, 프로모션 정보 제공" 마케팅 동의 조항(terms_content.dart:602,633)도 유지.
- **CLAUDE.md는 gitignored** — 수정하되 git add 하지 않는다.
- **배포 순서**: 백엔드(Slice 6) 먼저 배포 → 앱 릴리즈. 백엔드는 staging, 배포 앱 .env는 production — 배포 시 환경 일치 확인.
- **커밋 규약**: prefix `|FIX|`(Stage 0) / `|REMOVE|` / `|I18N|`, 메시지 끝에 `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` + `Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA` 두 줄.
- **알려진 환경 이슈**: 이 머신의 `flutter analyze`가 analysis server 크래시로 실패할 수 있음 (Dart SDK 캐시 스냅샷 누락). 복구: `rm -rf /Users/imdonghyeon/flutter/bin/cache/dart-sdk && flutter doctor` 후 재시도 (Task 0.1 Step 1에서 선복구). `flutter test`·backend pytest(47 passed 베이스라인)는 정상.
- **코드 밖 수동 작업 (사용자)**: App Store Connect에서 구독 상품 2종(perchcare_premium_monthly/yearly) 판매 중단 — Stage 1 앱 릴리즈 전까지.

## 루프 엔지니어링 규약 (모든 태스크 공통)

각 태스크의 마지막 스텝은 반드시 **검증 루프**다:

1. 검증 명령 실행 — 앱: `flutter analyze`(+ 해당 시 `flutter test`), 백엔드: `cd backend && python3 -m compileall app -q && python3 -c "import app.main" && python3 -m pytest app/tests -q`
2. 실패 시: 원인 수정 → 재실행. **통과할 때까지 반복** (기대 출력에 도달하기 전에는 다음 스텝으로 넘어가지 않는다)
3. 통과 시에만 커밋 → 다음 태스크로

각 태스크 완료 시점에 프로젝트는 항상 컴파일 가능해야 한다(참조 제거가 파일 삭제보다 선행). 검증 명령의 기대 출력은 각 태스크에 명시되어 있다.

## 전역 실행 순서

문서는 슬라이스별로 구성되어 있지만, **실행은 반드시 아래 순서**를 따른다 (의존성 반영):

| 순서 | 태스크 | 내용 | 의존성 |
|---|---|---|---|
| 1 | 0.1 → 0.2 → 0.3 | Stage 0: 펫 전환 버그 수정 + 회귀 테스트 + 수동 검증 | 없음 |
| 2 | 6.1 → 6.2 → … → 6.8 | 백엔드 프리미엄 제거 (앱 릴리즈 전 배포 필요) | 없음 (앱과 독립) |
| 3 | 5.1 | 중립 l10n 키 신설 (최선행) | 없음 |
| 4 | 2.1 → 2.2 → … → 2.6 | health_check 5화면 (2.1은 5.1 완료 시 skip 확인만) | 5.1 |
| 5 | 3.1 → 3.2 → 3.3 | ai_encyclopedia (3.1은 5.1 완료 시 skip 확인만) | 5.1 |
| 6 | 4.1 → 4.2 → 4.3 → 4.4 | home 도메인 isPremium 제거 (View→State→Repository 순) | 없음 |
| 7 | 1.1 → 1.2 → 1.3 → 1.4 | 앱 코어 배선·라우터 제거 | 없음 |
| 8 | 1.5 | 프리미엄 전용 파일 7개 삭제 (grep 잔존 참조 0건 게이트) | 2.x, 3.x, 4.x, 1.1~1.4 |
| 9 | 1.6 | AppConfig.premiumEnabled 플래그 제거 | 1.5, 3.x |
| 10 | 5.5 → 5.6 | coach_mark screenPremium·analytics 프리미엄 이벤트 제거 | 1.5 (호출처 소멸 후) |
| 11 | 5.2 → 5.3 → 5.4 | faq 프리미엄 카테고리·약관 조항·workspacePremium 아이콘 | 없음 |
| 12 | 5.7 | arb 3파일 프리미엄 키 전수 제거 + gen-l10n | 2.x, 3.x, 1.5, 5.2, 5.5 |
| 13 | 5.8 | in_app_purchase 의존성 + StoreKit 수동 링크 제거 | 1.5 |
| 14 | 5.9 | 문서 갱신 (quota-system.md, CLAUDE.md는 커밋 제외) | 전체 완료 후 |

---

## Slice 0 — Stage 0: 기록 탭 펫 전환 버그 수정

> **근본 원인 (코드 확인 완료)**: `weight_detail_screen.dart`의 `_switchPet()`(197-217행)이 로컬 setState + `_petCache.setActivePetId()` + `_petService.setActivePet()`만 수행하고 `activePetViewModelProvider`를 갱신하지 않는다. build()의 동기화 가드(360-367행)가 stale provider 값(이전 펫)을 감지해 `_switchPet(이전펫)`을 재호출 → 선택이 원복되고, 이 원복 경로가 이전 펫으로 `PUT /pets/{id}/activate`를 재발사해 서버 활성 펫까지 되돌린다.
>
> **수정 전략**: 탭 핸들러(2132행)는 `ref.read(activePetViewModelProvider.notifier).switchPet(pet.id)`(pet_profile_screen.dart:218-221과 동일 패턴, `active_pet_view_model.dart:24-29`의 `Future<void> switchPet(String petId)`)로 교체. `_switchPet`은 `_onActivePetChanged`로 개명하고 영속화 호출(`_petCache.setActivePetId`, `_petService.setActivePet`)을 제거해 **로컬 상태 리로드 전용**으로 만든다 — 가드 경유 호출이 더 이상 서버 재영속화를 하지 않는다. 흐름: 탭 → ViewModel이 영속화+provider 갱신 → build() 가드가 감지 → 로컬 리로드 (단방향).
>
> **환경 주의 (2026-07-05 확인)**: 이 머신의 `flutter analyze` / `dart analyze`는 현재 tool_crash로 실패한다 (Dart SDK 캐시 `/Users/imdonghyeon/flutter/bin/cache/dart-sdk/bin/snapshots/`에 analysis_server 스냅샷 누락, 서버 exit code 64). Task 0.1 Step 1에서 선복구한다. `flutter test`는 정상 동작 확인됨.

---

### Task 0.1: 펫 선택기 탭 경로를 ActivePetViewModel.switchPet 경유로 교체 + 가드 리로드의 서버 중복 발사 제거

**Files:**
- Modify: `/Users/imdonghyeon/perch_care/lib/src/screens/weight/weight_detail_screen.dart` (197-217행 `_switchPet`, 358-367행 build 가드, 2132행 onTap)

**Interfaces:**
- Consumes: `activePetViewModelProvider` (`AsyncNotifierProvider<ActivePetViewModel, Pet?>`, `lib/src/view_models/pet/active_pet_view_model.dart:38-39`, 화면에 이미 import된 `providers/pet_providers.dart`가 re-export), `ActivePetViewModel.switchPet(String petId) → Future<void>` (동 파일 24-29행)
- Produces: 없음 (화면 private 메서드 `_onActivePetChanged(Pet pet)`만 신설, 외부 태스크 의존 없음)

- [ ] **Step 1: 분석 도구 정상화 확인** — `flutter analyze` 실행. tool_crash(`analysis server exited with code 64`)로 죽으면 Dart SDK 캐시 복구 후 재시도:
  ```bash
  rm -rf /Users/imdonghyeon/flutter/bin/cache/dart-sdk && flutter doctor
  flutter analyze
  ```
  정상 동작하면 현재 베이스라인 출력(기존 info/warning 목록)을 기록해 둔다. 이 시점의 분석 결과가 이후 스텝의 비교 기준.

- [ ] **Step 2: `_switchPet`을 로컬 리로드 전용 `_onActivePetChanged`로 정리** — 영속화 2줄(`_petCache.setActivePetId`, `_petService.setActivePet`) 제거. `weight_detail_screen.dart` 197-217행 교체:

  old:
  ```dart
  Future<void> _switchPet(Pet pet) async {
    if (pet.id == _activePetId) return;
    setState(() {
      _activePetId = pet.id;
      _petName = pet.name;
      _weightRecords = [];
      _scheduleRecords = [];
      _cachedMonthlyAverages = null;
      _cachedWeeklyData = null;
      _cachedWeeklyStart = null;
    });
    _petCache.setActivePetId(pet.id);
    try {
      await _petService.setActivePet(pet.id);
    } catch (_) {}
    try {
      await Future.wait([_loadWeightData(), _loadScheduleData(), _loadDailyRecordData()]);
    } catch (_) {
      // 개별 로드 함수 내부에서 에러 처리
    }
  }
  ```

  new:
  ```dart
  /// 활성 펫 변경에 따른 로컬 상태 리로드 전용 메서드.
  ///
  /// 영속화(서버 `PUT /pets/{id}/activate` + provider 갱신)는
  /// `ActivePetViewModel.switchPet()`이 담당한다. 이 메서드는 build()의
  /// provider → 로컬 단방향 동기화 가드에서만 호출되며, 여기서 다시
  /// 영속화하면 stale provider 값으로 서버 활성 펫을 원복시키는
  /// 중복 발사가 되므로 절대 서버/캐시 쓰기를 하지 않는다.
  Future<void> _onActivePetChanged(Pet pet) async {
    if (pet.id == _activePetId) return;
    setState(() {
      _activePetId = pet.id;
      _petName = pet.name;
      _weightRecords = [];
      _scheduleRecords = [];
      _cachedMonthlyAverages = null;
      _cachedWeeklyData = null;
      _cachedWeeklyStart = null;
    });
    try {
      await Future.wait([_loadWeightData(), _loadScheduleData(), _loadDailyRecordData()]);
    } catch (_) {
      // 개별 로드 함수 내부에서 에러 처리
    }
  }
  ```
  참고: `_petCache`/`_petService` 필드는 `_loadActivePet()`(127-195행)에서 계속 사용되므로 삭제하지 않는다. `_dailyRecords`를 초기화하지 않는 것은 기존 동작 유지(구조 외 기능 변경 금지 원칙).

- [ ] **Step 3: build() 가드를 개명된 메서드 + 정식 provider 이름으로 갱신** — 360-367행 교체 (deprecated alias `activePetProvider` → 정식 `activePetViewModelProvider`, import 변경 불필요 — `providers/pet_providers.dart`가 re-export):

  old:
  ```dart
    final activePetAsync = ref.watch(activePetProvider);
    final activePet = activePetAsync.valueOrNull;
    // 펫 변경 감지 → _switchPet 호출
    if (activePet != null && activePet.id != _activePetId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _switchPet(activePet);
      });
    }
  ```

  new:
  ```dart
    final activePetAsync = ref.watch(activePetViewModelProvider);
    final activePet = activePetAsync.valueOrNull;
    // provider(SSOT) → 로컬 단방향 동기화: 활성 펫 변경 감지 시 로컬 상태 리로드
    if (activePet != null && activePet.id != _activePetId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onActivePetChanged(activePet);
      });
    }
  ```

- [ ] **Step 4: 펫 선택기 onTap을 ViewModel 경유로 교체** — 2132행 (`_buildPetSelector` 내부, pet_profile_screen.dart:218-221과 동일 패턴):

  old:
  ```dart
            onTap: () => _switchPet(pet),
  ```

  new:
  ```dart
            onTap: () => ref
                .read(activePetViewModelProvider.notifier)
                .switchPet(pet.id),
  ```
  동작 메모: `switchPet`은 `runLoad`(AsyncLoading.copyWithPrevious)로 실행되므로 서버 응답 전까지 provider는 이전 값을 유지 → pill 선택 표시는 응답 도착 후 가드 경유로 갱신된다(프로필 페이지와 동일한 UX).

- [ ] **Step 5: 검증 루프** — Run:
  ```bash
  flutter analyze
  flutter test
  ```
  기대 출력: `flutter analyze` → `No issues found!` (또는 Step 1 베이스라인 대비 신규 이슈 0건 — 특히 `_switchPet` 미정의 참조/unused import 없어야 함), `flutter test` → `All tests passed!`. 실패 시 원인 수정 후 재실행, 통과할 때까지 반복 → 통과 후 커밋:
  ```bash
  git add lib/src/screens/weight/weight_detail_screen.dart
  git commit -m "$(cat <<'EOF'
  |FIX| 기록 탭 펫 전환 원복 버그 — 선택기 탭을 ActivePetViewModel.switchPet 경유로 교체

  - 펫 선택기 onTap이 provider(SSOT)를 직접 갱신하도록 변경 (프로필 페이지와 동일 패턴)
  - _switchPet → _onActivePetChanged: 로컬 상태 리로드 전용으로 정리, 가드 경유 시
    이전 펫으로의 PUT /pets/{id}/activate 중복 발사 제거
  - build() 가드는 provider → 로컬 단방향 동기화로 유지

  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA
  EOF
  )"
  ```

---

### Task 0.2: ActivePetViewModel.switchPet 회귀 테스트 추가

**Files:**
- Create: `/Users/imdonghyeon/perch_care/test/view_models/pet/active_pet_view_model_test.dart`
- Test: 위 파일 자체 (기존 패턴: `test/view_models/pet/pet_list_view_model_test.dart` — 실행 통과 확인됨)

**Interfaces:**
- Consumes: `activePetViewModelProvider`, `PetRepository` (abstract, `lib/src/repositories/pet_repository.dart:10-48`), `petRepositoryProvider` (`lib/src/providers/repository_providers.dart`), `Pet` 생성자 (`id, userId, name, species, createdAt, updatedAt` — 기존 테스트와 동일 헬퍼 재사용)
- Produces: 없음

> **화면 위젯 테스트를 만들지 않는 근거**: `WeightDetailScreen`은 `WeightService.instance` 등 서비스 싱글턴 5개(Weight/Schedule/DailyRecord/Pet/PetLocalCache)를 필드에서 직접 참조하고 생성자·Provider 주입이 불가능해, 위젯 테스트에는 SharedPreferences·ApiClient까지 모킹하는 대규모 스캐폴딩이 필요하다(2,556줄 화면은 Stage 2에서 MVVM 전환 예정 — 그때 ViewModel 단위 테스트로 커버). Stage 0에서는 전환 경로의 SSOT인 `ActivePetViewModel` 단위 테스트 + Task 0.3 수동 검증으로 대체한다.

- [ ] **Step 1: 테스트 파일 생성** — `/Users/imdonghyeon/perch_care/test/view_models/pet/active_pet_view_model_test.dart`를 아래 내용으로 Write (기존 `pet_list_view_model_test.dart`의 mocktail + ProviderContainer 패턴 준수):

  ```dart
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:mocktail/mocktail.dart';

  import 'package:perch_care/src/models/pet.dart';
  import 'package:perch_care/src/providers/repository_providers.dart';
  import 'package:perch_care/src/repositories/pet_repository.dart';
  import 'package:perch_care/src/view_models/pet/active_pet_view_model.dart';

  class MockPetRepository extends Mock implements PetRepository {}

  Pet _pet(String id, {String name = 'Test'}) => Pet(
        id: id,
        userId: 'user-1',
        name: name,
        species: 'bird',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  /// Mock Repository를 주입한 ProviderContainer를 반환 (테스트 종료 시 자동 dispose).
  ProviderContainer _container(PetRepository repo) {
    final container = ProviderContainer(overrides: [
      petRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  void main() {
    late MockPetRepository repo;

    setUp(() {
      repo = MockPetRepository();
    });

    group('ActivePetViewModel', () {
      test('build()는 Repository.getActivePet()을 호출하고 결과를 노출한다', () async {
        when(() => repo.getActivePet(forceRefresh: false))
            .thenAnswer((_) async => _pet('p1'));

        final container = _container(repo);
        final pet = await container.read(activePetViewModelProvider.future);

        expect(pet?.id, 'p1');
        verify(() => repo.getActivePet(forceRefresh: false)).called(1);
      });

      // 기록 탭 펫 전환 버그(2026-07) 회귀 테스트:
      // 선택기 탭 경로는 반드시 이 switchPet을 경유해야 하며,
      // 영속화(setActivePet) → forceRefresh 재조회 → provider 상태 갱신 순서를 보장한다.
      test('switchPet()은 setActivePet 영속화 후 forceRefresh 재조회로 상태를 갱신한다',
          () async {
        when(() => repo.getActivePet(forceRefresh: false))
            .thenAnswer((_) async => _pet('p1'));
        when(() => repo.setActivePet('p2')).thenAnswer((_) async {});
        when(() => repo.getActivePet(forceRefresh: true))
            .thenAnswer((_) async => _pet('p2', name: 'Second'));

        final container = _container(repo);
        await container.read(activePetViewModelProvider.future); // 초기 로드 p1

        await container
            .read(activePetViewModelProvider.notifier)
            .switchPet('p2');

        final pet = container.read(activePetViewModelProvider).valueOrNull;
        expect(pet?.id, 'p2');
        verifyInOrder([
          () => repo.setActivePet('p2'),
          () => repo.getActivePet(forceRefresh: true),
        ]);
      });

      test('switchPet() 실패 시 AsyncError 상태로 전파된다', () async {
        when(() => repo.getActivePet(forceRefresh: false))
            .thenAnswer((_) async => _pet('p1'));
        when(() => repo.setActivePet('p2'))
            .thenThrow(Exception('network error'));

        final container = _container(repo);
        await container.read(activePetViewModelProvider.future);

        await container
            .read(activePetViewModelProvider.notifier)
            .switchPet('p2');

        final state = container.read(activePetViewModelProvider);
        expect(state.hasError, isTrue);
      });
    });
  }
  ```

- [ ] **Step 2: 검증 루프** — Run:
  ```bash
  flutter test test/view_models/pet/active_pet_view_model_test.dart
  flutter analyze
  flutter test
  ```
  기대 출력: 신규 테스트 3건 포함 `All tests passed!`, `flutter analyze` 신규 이슈 0건. 실패 시 원인 수정 후 재실행, 통과할 때까지 반복 → 통과 후 커밋:
  ```bash
  git add test/view_models/pet/active_pet_view_model_test.dart
  git commit -m "$(cat <<'EOF'
  |FIX| ActivePetViewModel 회귀 테스트 — switchPet 영속화·재조회 순서 및 에러 전파 검증

  기록 탭 펫 전환 원복 버그의 수정 경로(선택기 탭 → ViewModel.switchPet)를
  Repository mock 단위 테스트로 고정

  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA
  EOF
  )"
  ```

---

### Task 0.3: 수동 검증 — 펫 전환 유지·화면 간 일관성·재시작 영속성

**Files:**
- Test (수동): 앱 실행 검증만, 파일 변경 없음 (검증 중 결함 발견 시에만 `lib/src/screens/weight/weight_detail_screen.dart` 재수정)

**Interfaces:** 없음

> 전제: 테스트 계정에 펫 2마리 이상 등록되어 있어야 한다 (없으면 홈 → 펫 추가로 B 펫을 먼저 생성). 백엔드는 production(`perchcare-production.up.railway.app`) — `.env` 기준 정상 흐름.

- [ ] **Step 1: 앱 실행** — `flutter devices`로 디바이스 확인 후 `flutter run -d <device_id>` (iOS 시뮬레이터 권장). 로그인 → 홈 진입까지 확인.
- [ ] **Step 2: [체크 A] 기록 탭 전환 유지** — 하단 네비게이션에서 기록 탭(WeightDetailScreen) 진입 → 상단 펫 선택기에서 현재 비활성인 펫 B 탭 → **B pill이 선택 상태로 바뀐 뒤 이전 펫 A로 원복되지 않는지** 확인 (서버 응답까지 짧은 지연 후 갱신되는 것은 정상), 차트·일정·일일기록이 B 데이터로 리로드되는지 확인.
- [ ] **Step 3: [체크 B] 홈·프로필 일관성** — 홈 탭 이동 → 홈의 활성 펫이 B인지 확인. 프로필 페이지 진입 → 선택 카드가 B인지 확인. 이어서 프로필에서 A 탭으로 전환 → 기록 탭 재진입 시 선택기가 A로 동기화되는지 확인 (provider → 로컬 가드 역방향 경로 검증).
- [ ] **Step 4: [체크 C] 앱 재시작 영속성** — 기록 탭에서 B로 전환해 둔 상태에서 앱 완전 종료(스와이프 킬) → 재실행 → 활성 펫이 B로 유지되는지 확인 (버그 재현 시엔 이전 펫으로 되돌아갔음). 가능하면 `flutter run` 콘솔/백엔드 로그로 `PUT /pets/{B_id}/activate`가 1회만 발사되고 이전 펫 A로의 activate 재발사가 없는지 확인.
- [ ] **Step 5: 검증 루프** — 체크 A/B/C 중 하나라도 실패 시: superpowers:systematic-debugging으로 근본 원인 규명(추측 수정 금지) → `weight_detail_screen.dart` 수정 → `flutter analyze` + `flutter test` 재통과 → Step 1부터 수동 체크리스트 재검증, 전부 통과할 때까지 반복. 수정이 발생한 경우에만 커밋:
  ```bash
  git add lib/src/screens/weight/weight_detail_screen.dart
  git commit -m "$(cat <<'EOF'
  |FIX| 펫 전환 수동 검증 중 발견된 결함 보완 (기록 탭 전환 유지/재시작 영속성)

  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA
  EOF
  )"
  ```
  수정 없이 전부 통과하면 커밋 없이 Task 완료로 기록한다.

---

## Slice 6 — 백엔드 프리미엄 제거 (FastAPI, `/Users/imdonghyeon/perch_care/backend/`)

> **공통 노트**
> - **검증 환경 (사전 확인 완료)**: 백엔드 테스트는 `backend/app/tests/`에 존재하며 pytest 8.3.4가 requirements.txt에 있고, 현재 `python3 -m pytest app/tests -q` → **47 passed**, `python3 -c "import app.main"` 스모크도 통과한다 (stderr에 `VECTOR_DATABASE_URL not set — vector search disabled` 경고는 정상). 각 태스크의 검증 루프 명령: `cd /Users/imdonghyeon/perch_care/backend && python3 -m compileall app -q && python3 -c "import app.main" && python3 -m pytest app/tests -q` — 기대 출력: compileall 무출력·exit 0, import 성공, `47 passed`.
> - **중립 l10n 키**: `quota_limitReachedTitle`/`quota_limitReachedMessage`는 Flutter 슬라이스(.arb)에서 신설된다. 이 슬라이스는 백엔드 429/403 `detail` 문자열을 해당 ko 문구("이번 달 사용 한도에 도달했어요. 다음 달에 다시 이용할 수 있어요.")와 동일하게 정렬만 한다. 상태코드(429/403)는 유지 — 서버 쿼터 강제 지속.
> - **배포는 계획 범위 밖** — 사용자가 Railway로 직접 수행. 환경변수는 절대 변경하지 않는다(변경 시 자동 재배포 트리거). DB 테이블(`user_tiers`, `premium_codes`, `subscription_transactions`)은 보존, drop 마이그레이션 금지, `alembic/` 하위 파일 불변.
> - **순서 의존성**: 6.1→6.3이 `get_current_tier` 사용처를 라우터에서 제거, 6.4가 premium 라우터(=`tier_service`의 마지막 실호출처) 삭제, 6.5가 quota 시그니처 변경+나머지 `get_current_tier` 사용처 제거, 6.6이 `get_current_tier`·`tier_service.py` 삭제, 6.7이 `image_cleanup_service`의 `UserTier` 참조 제거, 6.8이 마지막으로 모델 파일 삭제. **참조 제거가 항상 파일 삭제에 선행한다.**

---

### Task 6.1: reports.py 프리미엄 게이트 제거 — 리포트 공유 전체 개방
**Files:**
- Modify: `/Users/imdonghyeon/perch_care/backend/app/routers/reports.py` (L1, L15, L85–L102, L130–L145)
**Interfaces:** Consumes: 없음. Produces: `POST /reports/share/health/{pet_id}`, `POST /reports/share/vet-summary/{pet_id}` — tier 의존 없는 시그니처 (클라이언트 슬라이스의 vet_summary/history 게이트 제거와 짝).

- [ ] **Step 1: 모듈 docstring에서 프리미엄 문구 제거** — old:
```python
"""건강 리포트 웹 링크 공유 엔드포인트 (프리미엄 전용)."""
```
new:
```python
"""건강 리포트 웹 링크 공유 엔드포인트."""
```
- [ ] **Step 2: import에서 get_current_tier 제거** — old:
```python
from app.dependencies import get_current_user, get_current_tier
```
new:
```python
from app.dependencies import get_current_user
```
- [ ] **Step 3: share_health_report의 tier 파라미터 + 403 게이트 제거** — old:
```python
    current_user: User = Depends(get_current_user),
    tier: str = Depends(get_current_tier),
):
    """건강 리포트 공유 링크 생성 (프리미엄 전용)."""
    if tier != "premium":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="프리미엄 전용 기능입니다",
        )

    if date_to < date_from:
```
new:
```python
    current_user: User = Depends(get_current_user),
):
    """건강 리포트 공유 링크 생성."""
    if date_to < date_from:
```
(`status` import는 바로 아래 `status.HTTP_400_BAD_REQUEST`에서 계속 사용되므로 유지)
- [ ] **Step 4: share_vet_summary의 tier 파라미터 + 403 게이트 제거** — old:
```python
    current_user: User = Depends(get_current_user),
    tier: str = Depends(get_current_tier),
):
    """병원 방문 요약 공유 링크 생성 (프리미엄 전용)."""
    if tier != "premium":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="프리미엄 전용 기능입니다",
        )

    language = request.headers.get("Accept-Language", "ko").split(",")[0].split("-")[0]
```
new:
```python
    current_user: User = Depends(get_current_user),
):
    """병원 방문 요약 공유 링크 생성."""
    language = request.headers.get("Accept-Language", "ko").split(",")[0].split("-")[0]
```
- [ ] **Step 5: 검증 루프** — Run: `cd /Users/imdonghyeon/perch_care/backend && python3 -m compileall app -q && python3 -c "import app.main" && python3 -m pytest app/tests -q` → 기대: exit 0 + `47 passed`. 추가 확인: `grep -n "get_current_tier\|premium" app/routers/reports.py` → 매치 0건. 실패 시 원인 수정 후 재실행, 통과할 때까지 반복 → 통과 후 커밋:
```
cd /Users/imdonghyeon/perch_care && git add backend/app/routers/reports.py && git commit -m "|REMOVE| 리포트 공유 프리미엄 게이트 제거 — 전체 사용자 개방

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
```

---

### Task 6.2: weekly_insights.py premium 필터 제거 — 전체 사용자 대상 생성
**Files:**
- Modify: `/Users/imdonghyeon/perch_care/backend/app/jobs/weekly_insights.py` (L1, L17, L44–L77, L84–L89)
**Interfaces:** Produces: `_get_users_with_pets(db) -> list[tuple[User, list[Pet]]]` (모듈 내부 전용). Consumes: 없음.

- [ ] **Step 1: 모듈 docstring 갱신** — old:
```python
"""Weekly insights job — generates AI health insights for premium users' pets.
```
new:
```python
"""Weekly insights job — generates AI health insights for all users' pets.
```
- [ ] **Step 2: UserTier import 제거** — old:
```python
from app.models.user_tier import UserTier
```
new: (라인 삭제)
- [ ] **Step 3: `_get_premium_users_with_pets` → `_get_users_with_pets` 교체** — old:
```python
async def _get_premium_users_with_pets(db: AsyncSession) -> list[tuple[User, list[Pet]]]:
    """Premium 사용자와 그 사용자의 활성 펫 목록을 반환."""
    from datetime import datetime, timezone

    now = datetime.now(timezone.utc)

    # Premium 사용자 ID 조회
    tier_result = await db.execute(
        select(UserTier.user_id).where(
            UserTier.tier == "premium",
            UserTier.premium_expires_at > now,
        )
    )
    premium_user_ids = [row for row in tier_result.scalars().all()]

    if not premium_user_ids:
        return []

    # 사용자 + 펫 조회
    user_result = await db.execute(
        select(User).where(User.id.in_(premium_user_ids))
    )
    users = list(user_result.scalars().all())

    result = []
    for user in users:
        pet_result = await db.execute(
            select(Pet).where(Pet.user_id == user.id)
        )
        pets = list(pet_result.scalars().all())
        if pets:
            result.append((user, pets))

    return result
```
new:
```python
async def _get_users_with_pets(db: AsyncSession) -> list[tuple[User, list[Pet]]]:
    """전체 사용자와 그 사용자의 펫 목록을 반환."""
    user_result = await db.execute(select(User))
    users = list(user_result.scalars().all())

    result = []
    for user in users:
        pet_result = await db.execute(
            select(Pet).where(Pet.user_id == user.id)
        )
        pets = list(pet_result.scalars().all())
        if pets:
            result.append((user, pets))

    return result
```
- [ ] **Step 4: run()의 호출부 + 로그 문구 갱신** — old:
```python
        # 1. Premium 사용자 + 펫 조회
        user_pets = await _get_premium_users_with_pets(db)
        logger.info(f"Premium users with pets: {len(user_pets)}")

        if not user_pets:
            logger.info("No premium users to generate insights for. Exiting.")
            return
```
new:
```python
        # 1. 전체 사용자 + 펫 조회
        user_pets = await _get_users_with_pets(db)
        logger.info(f"Users with pets: {len(user_pets)}")

        if not user_pets:
            logger.info("No users to generate insights for. Exiting.")
            return
```
- [ ] **Step 5: 검증 루프** — Run: `cd /Users/imdonghyeon/perch_care/backend && python3 -m compileall app -q && python3 -c "import app.jobs.weekly_insights" && python3 -m pytest app/tests -q` → 기대: exit 0 + `47 passed`. 추가 확인: `grep -n "UserTier\|premium" app/jobs/weekly_insights.py` → 매치 0건. 실패 시 수정 후 재실행 반복 → 통과 후 커밋:
```
cd /Users/imdonghyeon/perch_care && git add backend/app/jobs/weekly_insights.py && git commit -m "|REMOVE| 주간 인사이트 잡 premium 필터 제거 — 전체 사용자 대상 생성

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
```

---

### Task 6.3: pets.py tier 의존 제거 + health-summary 상세 필드 전원 개방
> **스코프 노트**: 슬라이스 지시문의 (d)에는 없지만, `get_current_tier` 사용처 전수 확인 결과 `routers/pets.py`(health-summary L128 · insights 게이트 L146)가 추가 사용처다. (e)의 선행 조건이므로 여기서 제거한다. 클라이언트 스펙("weekly insight 항상 조회", "`_buildPremiumDetails` 상세 섹션 전원 노출")과 정합.

**Files:**
- Modify: `/Users/imdonghyeon/perch_care/backend/app/routers/pets.py` (L6, L11, L123–L158)
- Modify: `/Users/imdonghyeon/perch_care/backend/app/services/health_summary_service.py` (L66–L68, L92–L125)
**Interfaces:** Produces: `get_health_summary(db: AsyncSession, pet_id: UUID, target_date: date) -> HealthSummaryResponse` (tier 파라미터 제거 — 유일 호출처는 pets.py, 본 태스크에서 함께 수정). `GET /pets/{pet_id}/insights` 403 게이트 제거. `HealthSummaryResponse` 스키마 필드는 불변(클라이언트 모델 필드 유지 방침).

- [ ] **Step 1: pets.py fastapi import 정리** (HTTPException/status는 insights 게이트에서만 사용됨 — 게이트 제거 후 미사용) — old:
```python
from fastapi import APIRouter, Depends, HTTPException, Query, status
```
new:
```python
from fastapi import APIRouter, Depends, Query
```
- [ ] **Step 2: pets.py dependencies import 정리** — old:
```python
from app.dependencies import get_current_user, get_current_user_id, get_current_tier
```
new:
```python
from app.dependencies import get_current_user, get_current_user_id
```
- [ ] **Step 3: health-summary 엔드포인트 tier 제거** — old:
```python
    current_user: User = Depends(get_current_user),
    tier: str = Depends(get_current_tier),
    db: AsyncSession = Depends(get_db),
):
    """건강 변화 요약 카드 데이터. Free: 기본 요약, Premium: 상세 카드."""
    # 소유권 확인
    await pet_service.get_pet_by_id(db, pet_id, current_user.id)
    return await get_health_summary(db, pet_id, tier, target_date)
```
new:
```python
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """건강 변화 요약 카드 데이터 (상세 필드 포함)."""
    # 소유권 확인
    await pet_service.get_pet_by_id(db, pet_id, current_user.id)
    return await get_health_summary(db, pet_id, target_date)
```
- [ ] **Step 4: insights 엔드포인트 프리미엄 게이트 제거** — old:
```python
@router.get(
    "/{pet_id}/insights",
    response_model=PetInsightResponse | None,
    responses={403: {"description": "Premium only"}},
)
async def get_pet_insights(
    pet_id: UUID,
    type: str = Query(default="weekly", pattern="^(weekly)$"),
    current_user: User = Depends(get_current_user),
    tier: str = Depends(get_current_tier),
    db: AsyncSession = Depends(get_db),
):
    """주간 건강 인사이트. Premium 전용.

    Lazy generation: DB에 인사이트가 없으면 백그라운드로 생성을 트리거하고 즉시 None 반환.
    다음 호출 시 결과 반환됨. cron(`weekly_insights.py`)을 기다리지 않아도 됨.
    """
    if tier != "premium":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="프리미엄 전용 기능입니다",
        )
    await pet_service.get_pet_by_id(db, pet_id, current_user.id)
```
new:
```python
@router.get(
    "/{pet_id}/insights",
    response_model=PetInsightResponse | None,
)
async def get_pet_insights(
    pet_id: UUID,
    type: str = Query(default="weekly", pattern="^(weekly)$"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """주간 건강 인사이트.

    Lazy generation: DB에 인사이트가 없으면 백그라운드로 생성을 트리거하고 즉시 None 반환.
    다음 호출 시 결과 반환됨. cron(`weekly_insights.py`)을 기다리지 않아도 됨.
    """
    await pet_service.get_pet_by_id(db, pet_id, current_user.id)
```
- [ ] **Step 5: health_summary_service.get_health_summary 시그니처에서 tier 제거** — old:
```python
async def get_health_summary(
    db: AsyncSession, pet_id: UUID, tier: str, target_date: date,
) -> HealthSummaryResponse:
```
new:
```python
async def get_health_summary(
    db: AsyncSession, pet_id: UUID, target_date: date,
) -> HealthSummaryResponse:
```
- [ ] **Step 6: 기본 응답 주석 정리** — old:
```python
    # 기본 응답 (Free + Premium 공통)
    resp = HealthSummaryResponse(
```
new:
```python
    # 기본 응답
    resp = HealthSummaryResponse(
```
- [ ] **Step 7: Premium 전용 상세 블록을 무조건 실행으로 dedent** — old:
```python
    # Premium 전용 상세 필드
    if tier == "premium":
        since_30d = target_date - timedelta(days=30)

        resp.abnormal_count = await _count_abnormals(db, pet_id, since_30d)
        resp.food_consistency = await _calc_consistency(
            db, pet_id, FoodRecord, FoodRecord.recorded_date, since_30d, target_date,
        )
        resp.water_consistency = await _calc_consistency(
            db, pet_id, WaterRecord, WaterRecord.recorded_date, since_30d, target_date,
        )

        # 7일 전 BHI로 추세 계산 (이건 다른 날짜 BHI라 별도 계산 불가피)
        bhi_prev_ctx = await calculate_bhi_with_context(db, pet_id, target_date - timedelta(days=7))
        bhi_prev = bhi_prev_ctx.response
        prev_has = bhi_prev.has_weight_data or bhi_prev.has_food_data or bhi_prev.has_water_data
        resp.bhi_previous = bhi_prev.bhi_score if prev_has else None
        resp.bhi_trend = _bhi_trend_label(
            bhi.bhi_score if has_data else None,
            resp.bhi_previous,
        )

    return resp
```
new:
```python
    # 상세 필드 (전체 사용자 제공)
    since_30d = target_date - timedelta(days=30)

    resp.abnormal_count = await _count_abnormals(db, pet_id, since_30d)
    resp.food_consistency = await _calc_consistency(
        db, pet_id, FoodRecord, FoodRecord.recorded_date, since_30d, target_date,
    )
    resp.water_consistency = await _calc_consistency(
        db, pet_id, WaterRecord, WaterRecord.recorded_date, since_30d, target_date,
    )

    # 7일 전 BHI로 추세 계산 (이건 다른 날짜 BHI라 별도 계산 불가피)
    bhi_prev_ctx = await calculate_bhi_with_context(db, pet_id, target_date - timedelta(days=7))
    bhi_prev = bhi_prev_ctx.response
    prev_has = bhi_prev.has_weight_data or bhi_prev.has_food_data or bhi_prev.has_water_data
    resp.bhi_previous = bhi_prev.bhi_score if prev_has else None
    resp.bhi_trend = _bhi_trend_label(
        bhi.bhi_score if has_data else None,
        resp.bhi_previous,
    )

    return resp
```
- [ ] **Step 8: 검증 루프** — Run: `cd /Users/imdonghyeon/perch_care/backend && python3 -m compileall app -q && python3 -c "import app.main" && python3 -m pytest app/tests -q` → 기대: exit 0 + `47 passed`. 추가 확인: `grep -n "tier" app/routers/pets.py app/services/health_summary_service.py` → 매치 0건. 실패 시 수정 후 재실행 반복 → 통과 후 커밋:
```
cd /Users/imdonghyeon/perch_care && git add backend/app/routers/pets.py backend/app/services/health_summary_service.py && git commit -m "|REMOVE| pets 라우터 tier 의존 제거 — 인사이트·건강요약 상세 전원 개방

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
```

---

### Task 6.4: premium 라우터 등록 해제 + premium 라우터/스키마 파일 삭제
> **주의**: `services/store_verification_service.py`는 `routers/premium.py`가 유일한 소비처(grep 전수 확인)라 함께 삭제한다(잔존 시 dead code). `models/subscription_transaction.py`는 (g) 범위 밖이므로 유지(테이블 보존과 일관). **결정 필요 노트**: `app/templates/admin.html`(관리자 대시보드)은 `BASE = '/api/v1/premium'`으로 premium admin API에 전면 의존한다 — 라우터 삭제 후 admin 페이지의 프리미엄 관리 기능은 동작 불가. 스펙 범위 밖이므로 이 계획에서는 건드리지 않고 사용자 확인 사항으로 남긴다.

**Files:**
- Modify: `/Users/imdonghyeon/perch_care/backend/app/main.py` (L14, L101)
- Delete: `/Users/imdonghyeon/perch_care/backend/app/routers/premium.py`, `/Users/imdonghyeon/perch_care/backend/app/schemas/premium.py`, `/Users/imdonghyeon/perch_care/backend/app/services/store_verification_service.py`
**Interfaces:** Consumes: 없음. Produces: 없음 (제거 전용 — 이후 태스크에서 `tier_service`의 실호출처가 `dependencies.py`만 남게 만든다).

- [ ] **Step 1: main.py 라우터 import에서 premium 제거** — old:
```python
from app.routers import auth, users, pets, weights, daily_records, food_records, water_records, health_checks, schedules, notifications, bhi, ai, premium, breed_standards, chat, reports, demo
```
new:
```python
from app.routers import auth, users, pets, weights, daily_records, food_records, water_records, health_checks, schedules, notifications, bhi, ai, breed_standards, chat, reports, demo
```
- [ ] **Step 2: main.py 라우터 등록 제거** — old:
```python
app.include_router(ai.router, prefix=settings.api_v1_prefix)
app.include_router(premium.router, prefix=settings.api_v1_prefix)
app.include_router(breed_standards.router, prefix=settings.api_v1_prefix)
```
new:
```python
app.include_router(ai.router, prefix=settings.api_v1_prefix)
app.include_router(breed_standards.router, prefix=settings.api_v1_prefix)
```
- [ ] **Step 3: 파일 삭제** — Run:
```
cd /Users/imdonghyeon/perch_care && git rm backend/app/routers/premium.py backend/app/schemas/premium.py backend/app/services/store_verification_service.py
```
- [ ] **Step 4: 잔존 참조 확인** — Run: `cd /Users/imdonghyeon/perch_care/backend && grep -rn "routers import.*premium\|routers.premium\|schemas.premium\|store_verification" app/ --include="*.py" | grep -v __pycache__` → 기대: 매치 0건.
- [ ] **Step 5: 검증 루프** — Run: `cd /Users/imdonghyeon/perch_care/backend && python3 -m compileall app -q && python3 -c "import app.main" && python3 -m pytest app/tests -q` → 기대: exit 0 + `47 passed`. 실패 시 수정 후 재실행 반복 → 통과 후 커밋:
```
cd /Users/imdonghyeon/perch_care && git add backend/app/main.py && git commit -m "|REMOVE| premium 라우터·스키마·스토어 검증 서비스 삭제, main.py 등록 해제

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
```

---

### Task 6.5: quota_service tier 의존 제거 + ai.py/health_checks.py 분기 제거 (쿼터 강제는 유지)
> **핵심 계약 변경**: `check_and_reserve_*`에서 `tier` 파라미터 제거 → 전원 free 한도(`config.py`: `free_encyclopedia_monthly_limit=30`, `free_vision_monthly_limit=10` — **불변**). premium 무제한 분기가 사라지므로 `allowed=True`일 때 reservation은 항상 non-None → 호출부의 "Premium 새 로그 생성" else 분기는 dead code로 함께 제거. 429/403 상태코드는 유지, detail만 중립 문구로 정렬. `ai_service`의 `tier` 파라미터(전부 기본값 보유, 내부적으로 사실상 미사용 — `_select_model`·`_build_system_prompt` 모두 tier 무시 확인됨)는 이 슬라이스 범위 밖이므로 시그니처는 두고 라우터에서 인자 전달만 중단한다. `AiVisionLog.tier` DB 컬럼은 보존(마이그레이션 금지) — `"free"` 고정 기록.

**Files:**
- Modify: `/Users/imdonghyeon/perch_care/backend/app/services/quota_service.py` (L1–L9, L58–L87, L90–L149, L209–L238, L241–L298)
- Modify: `/Users/imdonghyeon/perch_care/backend/app/routers/ai.py` (L14–L17, L47–L67, L72–L101, L111–L143, L148–L162, L236–L246, L304–L308, L314–L326, L343–L361, L366–L374)
- Modify: `/Users/imdonghyeon/perch_care/backend/app/routers/health_checks.py` (L16–L17, L165–L169, L218–L226, L233–L245, L280–L299)
**Interfaces:** Produces (다른 코드가 의존하는 새 시그니처):
- `check_encyclopedia_quota(db: AsyncSession, user_id: UUID) -> dict`
- `check_and_reserve_encyclopedia(db: AsyncSession, user_id: UUID, pet_id: UUID | None, query_length: int, model: str) -> tuple[dict, AiEncyclopediaLog | None]`
- `check_vision_access(db: AsyncSession, user_id: UUID) -> dict`
- `check_and_reserve_vision(db: AsyncSession, user_id: UUID, pet_id: UUID | None, mode: str, part: str | None, image_size_bytes: int) -> tuple[dict, AiVisionLog | None]`
- `get_combined_free_usage_this_month`는 이 시점에 `tier_service`(6.6에서 삭제)가 아직 호출하므로 **유지** — 6.6에서 제거.

- [ ] **Step 1: quota_service 모듈 docstring 갱신** — old:
```python
"""AI 기능 사용량 쿼터 관리 서비스.

Free 사용자의 AI 백과사전·Vision 건강체크 월간 한도를 관리한다.
```
new:
```python
"""AI 기능 사용량 쿼터 관리 서비스.

전체 사용자 공통으로 AI 백과사전·Vision 건강체크 월간 한도를 관리한다.
```
- [ ] **Step 2: check_encyclopedia_quota에서 tier 제거** — old:
```python
async def check_encyclopedia_quota(
    db: AsyncSession, user_id: UUID, tier: str
) -> dict:
    """AI 백과사전 쿼터를 확인한다 (읽기 전용 — GET /premium/tier, GET /ai/quota 등에서 사용).

    Returns:
        {
            "allowed": bool,
            "monthly_limit": int,   # -1 = 무제한
            "monthly_used": int,
            "remaining": int,       # -1 = 무제한
        }
    """
    if tier == "premium":
        return {
            "allowed": True,
            "monthly_limit": -1,
            "monthly_used": 0,
            "remaining": -1,
        }

    used = await get_encyclopedia_usage_this_month(db, user_id)
```
new:
```python
async def check_encyclopedia_quota(db: AsyncSession, user_id: UUID) -> dict:
    """AI 백과사전 쿼터를 확인한다 (읽기 전용 — GET /ai/quota 등에서 사용).

    Returns:
        {
            "allowed": bool,
            "monthly_limit": int,
            "monthly_used": int,
            "remaining": int,
        }
    """
    used = await get_encyclopedia_usage_this_month(db, user_id)
```
- [ ] **Step 3: check_and_reserve_encyclopedia에서 tier 제거** — old:
```python
async def check_and_reserve_encyclopedia(
    db: AsyncSession,
    user_id: UUID,
    tier: str,
    pet_id: UUID | None,
    query_length: int,
    model: str,
) -> tuple[dict, AiEncyclopediaLog | None]:
    """쿼터 체크 + 슬롯 예약을 원자적으로 수행한다.

    pg_advisory_xact_lock으로 사용자별 직렬화하여 동시 요청에 의한 한도 초과를 방지.
    Premium 사용자는 잠금/예약 없이 통과.

    Returns:
        (quota_info, reservation_or_None)
        - reservation이 반환되면, 호출자가 AI 완료 후 response_length/response_time_ms를 업데이트.
        - AI 실패 시 트랜잭션 rollback으로 예약 자동 삭제 (Depends(get_db) 패턴).
          별도 세션에서 사용할 경우 호출자가 명시적으로 삭제해야 한다.
    """
    if tier == "premium":
        return {
            "allowed": True,
            "monthly_limit": -1,
            "monthly_used": 0,
            "remaining": -1,
        }, None

    # 사용자별 advisory lock 획득 (트랜잭션 종료 시 자동 해제)
```
new:
```python
async def check_and_reserve_encyclopedia(
    db: AsyncSession,
    user_id: UUID,
    pet_id: UUID | None,
    query_length: int,
    model: str,
) -> tuple[dict, AiEncyclopediaLog | None]:
    """쿼터 체크 + 슬롯 예약을 원자적으로 수행한다.

    pg_advisory_xact_lock으로 사용자별 직렬화하여 동시 요청에 의한 한도 초과를 방지.

    Returns:
        (quota_info, reservation_or_None)
        - allowed=True면 reservation이 반환되고, 호출자가 AI 완료 후
          response_length/response_time_ms를 업데이트.
        - AI 실패 시 트랜잭션 rollback으로 예약 자동 삭제 (Depends(get_db) 패턴).
          별도 세션에서 사용할 경우 호출자가 명시적으로 삭제해야 한다.
    """
    # 사용자별 advisory lock 획득 (트랜잭션 종료 시 자동 해제)
```
(이하 lock 획득부터 return까지의 본문은 불변)
- [ ] **Step 4: check_vision_access에서 tier 제거** — old:
```python
async def check_vision_access(
    db: AsyncSession, user_id: UUID, tier: str
) -> dict:
    """Vision 건강체크 접근 권한을 확인한다 (읽기 전용).

    Returns:
        {
            "allowed": bool,
            "monthly_limit": int,   # -1 = 무제한
            "monthly_used": int,
            "remaining": int,       # -1 = 무제한
        }
    """
    if tier == "premium":
        return {
            "allowed": True,
            "monthly_limit": -1,
            "monthly_used": 0,
            "remaining": -1,
        }

    used = await get_vision_usage_this_month(db, user_id)
```
new:
```python
async def check_vision_access(db: AsyncSession, user_id: UUID) -> dict:
    """Vision 건강체크 접근 권한을 확인한다 (읽기 전용).

    Returns:
        {
            "allowed": bool,
            "monthly_limit": int,
            "monthly_used": int,
            "remaining": int,
        }
    """
    used = await get_vision_usage_this_month(db, user_id)
```
- [ ] **Step 5: check_and_reserve_vision에서 tier 제거 + 로그 tier 고정** — old:
```python
async def check_and_reserve_vision(
    db: AsyncSession,
    user_id: UUID,
    tier: str,
    pet_id: UUID | None,
    mode: str,
    part: str | None,
    image_size_bytes: int,
) -> tuple[dict, AiVisionLog | None]:
    """Vision 접근 권한 체크 + 슬롯 예약을 원자적으로 수행한다.

    Returns:
        (access_info, reservation_or_None)
        - reservation이 반환되면, 호출자가 AI 완료 후 response_time_ms 등을 업데이트.
    """
    if tier == "premium":
        return {
            "allowed": True,
            "monthly_limit": -1,
            "monthly_used": 0,
            "remaining": -1,
        }, None

    await db.execute(
```
new:
```python
async def check_and_reserve_vision(
    db: AsyncSession,
    user_id: UUID,
    pet_id: UUID | None,
    mode: str,
    part: str | None,
    image_size_bytes: int,
) -> tuple[dict, AiVisionLog | None]:
    """Vision 접근 권한 체크 + 슬롯 예약을 원자적으로 수행한다.

    Returns:
        (access_info, reservation_or_None)
        - allowed=True면 reservation이 반환되고, 호출자가 AI 완료 후 response_time_ms 등을 업데이트.
    """
    await db.execute(
```
그리고 예약 생성부 — old:
```python
        image_size_bytes=image_size_bytes,
        response_time_ms=0,
        model="gpt-4o",
        tier=tier,
    )
```
new:
```python
        image_size_bytes=image_size_bytes,
        response_time_ms=0,
        model="gpt-4o",
        tier="free",  # 레거시 컬럼 — DB 스키마 보존을 위해 고정값 기록
    )
```
- [ ] **Step 6: ai.py import 정리** — old:
```python
from app.dependencies import get_current_user, get_current_tier
from app.models.user import User
from app.models.ai_encyclopedia_log import AiEncyclopediaLog
from app.models.ai_vision_log import AiVisionLog
```
new:
```python
from app.dependencies import get_current_user
from app.models.user import User
from app.models.ai_encyclopedia_log import AiEncyclopediaLog
```
(`AiEncyclopediaLog`는 stream finally의 delete/update에서 계속 사용 — 유지)
- [ ] **Step 7: /ai/encyclopedia 엔드포인트 tier 제거** — old:
```python
async def encyclopedia(
    body: AiEncyclopediaRequest,
    current_user: User = Depends(get_current_user),
    tier: str = Depends(get_current_tier),
    db: AsyncSession = Depends(get_db),
):
    model, _ = ai_service._select_model(tier)
```
new:
```python
async def encyclopedia(
    body: AiEncyclopediaRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    model, _ = ai_service._select_model("free")
```
- [ ] **Step 8: /ai/encyclopedia 쿼터 호출 + 429 detail 중립화** — old:
```python
    quota, reservation = await check_and_reserve_encyclopedia(
        db, current_user.id, tier, pet_uuid, len(body.query), model,
    )
    if not quota["allowed"]:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="일일 무료 사용량을 초과했습니다. 내일 다시 시도하거나 프리미엄을 구독하세요.",
        )
```
new:
```python
    quota, reservation = await check_and_reserve_encyclopedia(
        db, current_user.id, pet_uuid, len(body.query), model,
    )
    if not quota["allowed"]:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="이번 달 사용 한도에 도달했어요. 다음 달에 다시 이용할 수 있어요.",
        )
```
- [ ] **Step 9: /ai/encyclopedia ask 호출에서 tier 인자 제거** — old:
```python
    raw_answer = await ai_service.ask(
        db=db,
        query=body.query,
        history=body.history,
        tier=tier,
        pet_id=body.pet_id,
```
new:
```python
    raw_answer = await ai_service.ask(
        db=db,
        query=body.query,
        history=body.history,
        pet_id=body.pet_id,
```
- [ ] **Step 10: /ai/encyclopedia premium 로그 분기 제거** — old:
```python
    if reservation:
        # Free 사용자: 예약 로그 업데이트
        reservation.response_length = len(parsed["answer"])
        reservation.response_time_ms = elapsed_ms
    else:
        # Premium 사용자: 새 로그 생성
        db.add(AiEncyclopediaLog(
            user_id=current_user.id,
            pet_id=pet_uuid,
            query_length=len(body.query),
            response_length=len(parsed["answer"]),
            response_time_ms=elapsed_ms,
            model=model,
            tokens_used=None,
        ))
```
new:
```python
    if reservation:
        # 예약 로그 업데이트 (allowed=True면 항상 존재)
        reservation.response_length = len(parsed["answer"])
        reservation.response_time_ms = elapsed_ms
```
- [ ] **Step 11: /ai/encyclopedia/stream 시그니처 + 모델 선택** — old:
```python
async def encyclopedia_stream(
    body: AiEncyclopediaRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    tier: str = Depends(get_current_tier),
):
    """SSE 스트리밍으로 AI 백과사전 응답을 실시간 전송한다."""
    model, tier_max_tokens = ai_service._select_model(tier)
```
new:
```python
async def encyclopedia_stream(
    body: AiEncyclopediaRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
):
    """SSE 스트리밍으로 AI 백과사전 응답을 실시간 전송한다."""
    model, tier_max_tokens = ai_service._select_model("free")
```
- [ ] **Step 12: stream 쿼터 호출 + 429 detail 중립화** — old:
```python
        quota, reservation = await check_and_reserve_encyclopedia(
            quota_db, current_user.id, tier, pet_uuid, len(body.query), model,
        )
        if not quota["allowed"]:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="일일 무료 사용량을 초과했습니다. 내일 다시 시도하거나 프리미엄을 구독하세요.",
            )
```
new:
```python
        quota, reservation = await check_and_reserve_encyclopedia(
            quota_db, current_user.id, pet_uuid, len(body.query), model,
        )
        if not quota["allowed"]:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="이번 달 사용 한도에 도달했어요. 다음 달에 다시 이용할 수 있어요.",
            )
```
- [ ] **Step 13: stream prepare_system_message에서 tier 제거 + 미사용 캡처 변수 제거** — old:
```python
        system_message = await ai_service.prepare_system_message(
            db=prefetch_db,
            query=body.query,
            pet_id=body.pet_id,
            pet_profile_context=body.pet_profile_context,
            user_id=current_user.id,
            tier=tier,
        )

    # 캡처한 값들 — 제너레이터 내부에서 DB 불필요
    user_id = current_user.id
    query_text = body.query
```
new:
```python
        system_message = await ai_service.prepare_system_message(
            db=prefetch_db,
            query=body.query,
            pet_id=body.pet_id,
            pet_profile_context=body.pet_profile_context,
            user_id=current_user.id,
        )

    # 캡처한 값들 — 제너레이터 내부에서 DB 불필요
    query_text = body.query
```
(`user_id`는 아래 Step 14에서 제거되는 premium 로그 분기에서만 사용됨)
- [ ] **Step 14: stream finally의 premium 로그 분기 제거** — old:
```python
                    else:
                        # Premium 사용자: 새 로그 생성
                        log_session.add(AiEncyclopediaLog(
                            user_id=user_id,
                            pet_id=pet_uuid,
                            query_length=len(query_text),
                            response_length=len(full_response),
                            response_time_ms=elapsed_ms,
                            model=model,
                            tokens_used=None,
                        ))
                    await log_session.commit()
```
new:
```python
                    await log_session.commit()
```
- [ ] **Step 15: /ai/vision/analyze tier 제거 + 403 detail 중립화** — 시그니처 old:
```python
    current_user: User = Depends(get_current_user),
    tier: str = Depends(get_current_tier),
    db: AsyncSession = Depends(get_db),
):
    """펫 없이 Vision 분석 (food 모드 전용). DB 저장 없이 결과만 반환."""
```
new:
```python
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """펫 없이 Vision 분석 (food 모드 전용). DB 저장 없이 결과만 반환."""
```
쿼터 호출 old:
```python
    vis, reservation = await check_and_reserve_vision(
        db, current_user.id, tier, None, mode, part, len(image_bytes),
    )
    if not vis["allowed"]:
        raise HTTPException(status_code=403, detail="프리미엄 전용 기능입니다")
```
new:
```python
    vis, reservation = await check_and_reserve_vision(
        db, current_user.id, None, mode, part, len(image_bytes),
    )
    if not vis["allowed"]:
        raise HTTPException(status_code=403, detail="이번 달 사용 한도에 도달했어요. 다음 달에 다시 이용할 수 있어요.")
```
analyze 호출 old:
```python
            mode=mode,
            part=part,
            notes=notes,
            tier=tier,
            language=language,
        )
```
new:
```python
            mode=mode,
            part=part,
            notes=notes,
            language=language,
        )
```
로그 분기 old:
```python
    if reservation:
        # Free 사용자: 예약 로그 업데이트
        reservation.response_time_ms = elapsed_ms
        reservation.confidence_score = confidence
        reservation.overall_status = overall_status
    else:
        # Premium 사용자: 새 로그 생성
        db.add(AiVisionLog(
            user_id=current_user.id,
            pet_id=None,
            mode=mode,
            part=part,
            image_size_bytes=len(image_bytes),
            response_time_ms=elapsed_ms,
            model="gpt-4o",
            tier=tier,
            confidence_score=confidence,
            overall_status=overall_status,
        ))
```
new:
```python
    if reservation:
        # 예약 로그 업데이트 (allowed=True면 항상 존재)
        reservation.response_time_ms = elapsed_ms
        reservation.confidence_score = confidence
        reservation.overall_status = overall_status
```
- [ ] **Step 16: /ai/quota 엔드포인트 tier 제거 (쿼터 조회 자체는 유지)** — old:
```python
async def get_ai_quota(
    current_user: User = Depends(get_current_user),
    tier: str = Depends(get_current_tier),
    db: AsyncSession = Depends(get_db),
):
    """현재 사용자의 AI 기능 쿼터를 조회한다."""
    enc = await check_encyclopedia_quota(db, current_user.id, tier)
    vis = await check_vision_access(db, current_user.id, tier)
```
new:
```python
async def get_ai_quota(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """현재 사용자의 AI 기능 쿼터를 조회한다."""
    enc = await check_encyclopedia_quota(db, current_user.id)
    vis = await check_vision_access(db, current_user.id)
```
- [ ] **Step 17: health_checks.py import 정리** — old:
```python
from app.dependencies import get_current_user, get_current_tier, verify_pet_ownership
from app.models.ai_vision_log import AiVisionLog
from app.models.pet import Pet
```
new:
```python
from app.dependencies import get_current_user, verify_pet_ownership
from app.models.pet import Pet
```
- [ ] **Step 18: /analyze 시그니처 + docstring** — old:
```python
    current_user: User = Depends(get_current_user),
    tier: str = Depends(get_current_tier),
    db: AsyncSession = Depends(get_db),
):
    """GPT-4o Vision으로 이미지를 분석하여 건강 상태를 반환한다. 프리미엄 전용."""
```
new:
```python
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """GPT-4o Vision으로 이미지를 분석하여 건강 상태를 반환한다."""
```
- [ ] **Step 19: /analyze 쿼터 호출 + 403 detail 중립화** — old:
```python
    # 5. 티어 검증 + 슬롯 예약 (advisory lock으로 동시 요청 방지)
    vis, reservation = await check_and_reserve_vision(
        db, current_user.id, tier, pet_id, mode, part, len(image_bytes),
    )
    if not vis["allowed"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="프리미엄 전용 기능입니다",
        )
```
new:
```python
    # 5. 쿼터 체크 + 슬롯 예약 (advisory lock으로 동시 요청 방지)
    vis, reservation = await check_and_reserve_vision(
        db, current_user.id, pet_id, mode, part, len(image_bytes),
    )
    if not vis["allowed"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="이번 달 사용 한도에 도달했어요. 다음 달에 다시 이용할 수 있어요.",
        )
```
- [ ] **Step 20: /analyze의 ai_service 호출에서 tier 인자 제거** — old:
```python
            mode=mode,
            part=part,
            notes=notes,
            tier=tier,
            language=language,
        )
```
new:
```python
            mode=mode,
            part=part,
            notes=notes,
            language=language,
        )
```
- [ ] **Step 21: /analyze premium 로그 분기 제거** — old:
```python
    elapsed_ms = int((time.monotonic() - start_time) * 1000)
    if reservation:
        # Free 사용자: 예약 로그 업데이트
        reservation.response_time_ms = elapsed_ms
        reservation.confidence_score = confidence
        reservation.overall_status = overall_status
    else:
        # Premium 사용자: 새 로그 생성
        db.add(AiVisionLog(
            user_id=current_user.id,
            pet_id=pet_id,
            mode=mode,
            part=part,
            image_size_bytes=len(image_bytes),
            response_time_ms=elapsed_ms,
            model="gpt-4o",
            tier=tier,
            confidence_score=confidence,
            overall_status=overall_status,
        ))
```
new:
```python
    elapsed_ms = int((time.monotonic() - start_time) * 1000)
    if reservation:
        # 예약 로그 업데이트 (allowed=True면 항상 존재)
        reservation.response_time_ms = elapsed_ms
        reservation.confidence_score = confidence
        reservation.overall_status = overall_status
```
- [ ] **Step 22: 검증 루프** — Run: `cd /Users/imdonghyeon/perch_care/backend && python3 -m compileall app -q && python3 -c "import app.main" && python3 -m pytest app/tests -q` → 기대: exit 0 + `47 passed`. 추가 확인: `grep -rn "get_current_tier" app/routers/ --include="*.py" | grep -v __pycache__` → 매치 0건 (이제 dependencies.py 정의만 잔존). 실패 시 수정 후 재실행 반복 → 통과 후 커밋:
```
cd /Users/imdonghyeon/perch_care && git add backend/app/services/quota_service.py backend/app/routers/ai.py backend/app/routers/health_checks.py && git commit -m "|REMOVE| 쿼터 서비스 tier 의존 제거 — 전원 free 한도(백과사전 30/비전 10), 429/403 유지·중립 문구화

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
```

---

### Task 6.6: dependencies.get_current_tier 삭제 + tier_service.py 삭제 + quota dead 헬퍼 제거
> **선행 조건 충족 확인**: 6.1(reports)·6.3(pets)·6.4(premium 라우터)·6.5(ai/health_checks)로 `get_current_tier`의 모든 사용처가 제거됨. `tier_service`의 소비처는 `dependencies.py`가 유일(같은 태스크에서 함께 제거). `get_combined_free_usage_this_month`는 `tier_service`가 유일한 호출처였으므로 여기서 함께 삭제.

**Files:**
- Modify: `/Users/imdonghyeon/perch_care/backend/app/dependencies.py` (L1, L10, L88–L93)
- Modify: `/Users/imdonghyeon/perch_care/backend/app/services/quota_service.py` (L152–L184의 `get_combined_free_usage_this_month` 함수 — 6.5 적용 후 라인은 다소 이동)
- Delete: `/Users/imdonghyeon/perch_care/backend/app/services/tier_service.py`
**Interfaces:** Consumes: Task 6.1/6.3/6.4/6.5 완료 (get_current_tier 사용처 0건). Produces: 없음 (제거 전용).

- [ ] **Step 1: dependencies.py에서 Literal import 제거** (get_current_tier 반환 타입에서만 사용) — old:
```python
from typing import Literal
from uuid import UUID
```
new:
```python
from uuid import UUID
```
- [ ] **Step 2: tier_service import 제거** — old:
```python
from app.utils.security import decode_token
from app.services.tier_service import get_user_tier
from app.models.pet import Pet
```
new:
```python
from app.utils.security import decode_token
from app.models.pet import Pet
```
- [ ] **Step 3: get_current_tier 함수 삭제** — old:
```python


async def get_current_tier(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Literal["free", "premium"]:
    """현재 사용자의 티어 반환 ('free' 또는 'premium')."""
    return await get_user_tier(db, current_user.id)
```
new: (블록 전체 삭제 — 파일은 `verify_admin_api_key`로 끝남)
- [ ] **Step 4: quota_service에서 dead 헬퍼 삭제** — old:
```python
async def get_combined_free_usage_this_month(
    db: AsyncSession, user_id: UUID
) -> tuple[int, int]:
    """이번 달 (encyclopedia 사용량, vision 사용량)을 단일 SQL round-trip으로 반환.

    GET /premium/tier 응답 시간 단축을 위해 두 count 쿼리를 하나의 SELECT로 통합.
    AsyncSession 동시성 제약으로 asyncio.gather를 쓰면 InvalidRequestError 위험이 있어
    SQL 레벨에서 통합한다.
    """
    now = datetime.now(timezone.utc)
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

    enc_subq = (
        select(func.count())
        .select_from(AiEncyclopediaLog)
        .where(
            AiEncyclopediaLog.user_id == user_id,
            AiEncyclopediaLog.created_at >= month_start,
        )
        .scalar_subquery()
    )
    vis_subq = (
        select(func.count())
        .select_from(AiVisionLog)
        .where(
            AiVisionLog.user_id == user_id,
            AiVisionLog.created_at >= month_start,
        )
        .scalar_subquery()
    )
    result = await db.execute(select(enc_subq, vis_subq))
    enc_used, vis_used = result.one()
    return int(enc_used or 0), int(vis_used or 0)


```
new: (함수 전체 삭제. 삭제 후 `from sqlalchemy import func, select, text` import는 나머지 함수들이 모두 사용하므로 불변)
- [ ] **Step 5: tier_service.py 삭제** — Run:
```
cd /Users/imdonghyeon/perch_care && git rm backend/app/services/tier_service.py
```
- [ ] **Step 6: 잔존 참조 전수 확인** — Run: `cd /Users/imdonghyeon/perch_care/backend && grep -rn "get_current_tier\|tier_service\|get_combined_free_usage" app/ --include="*.py" | grep -v __pycache__` → 기대: 매치 0건.
- [ ] **Step 7: 검증 루프** — Run: `cd /Users/imdonghyeon/perch_care/backend && python3 -m compileall app -q && python3 -c "import app.main" && python3 -m pytest app/tests -q` → 기대: exit 0 + `47 passed`. 실패 시 수정 후 재실행 반복 → 통과 후 커밋:
```
cd /Users/imdonghyeon/perch_care && git add backend/app/dependencies.py backend/app/services/quota_service.py && git commit -m "|REMOVE| get_current_tier·tier_service 삭제 — 전원 free 취급

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
```

---

### Task 6.7: image_cleanup_service 단순화 — 프리미엄 만료 90일 정리 제거, 전원 동일 30일 보존
> **설계 판단 (실코드 기준)**: 현재 두 정리 메커니즘이 공존 — (1) `get_cleanup_candidates`+`process_cleanups`: "프리미엄 만료 후 90일 경과" 유저의 건강체크 이미지 일괄 삭제(UserTier 의존), (2) `cleanup_expired_health_check_images`: 전 사용자 대상 30일 초과 이미지 삭제. 프리미엄 개념이 사라지면 (1)은 존재 의의가 없고 (2)가 이미 전원 동일 보존 정책(30일)이므로, **(1) 전체 삭제 + (2) 유지**가 맞는 단순화다. 스케줄러 잡도 (2)만 호출하도록 축소.

**Files:**
- Modify: `/Users/imdonghyeon/perch_care/backend/app/services/image_cleanup_service.py` (L1–L73)
- Modify: `/Users/imdonghyeon/perch_care/backend/app/scheduler.py` (L11–L29)
**Interfaces:** Produces: `cleanup_expired_health_check_images(db) -> int` (유지, 시그니처 불변). `get_cleanup_candidates`/`process_cleanups`/`IMAGE_RETENTION_DAYS` 제거 (스케줄러 외 호출처 없음 — 전수 확인 완료).

- [ ] **Step 1: image_cleanup_service 헤더에서 UserTier import + 90일 상수 제거** — old:
```python
import logging
from datetime import datetime, timezone, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user_tier import UserTier
from app.models.ai_health_check import AiHealthCheck

logger = logging.getLogger(__name__)

IMAGE_RETENTION_DAYS = 90
HEALTH_CHECK_IMAGE_RETENTION_DAYS = 30
```
new:
```python
import logging
from datetime import datetime, timezone, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.ai_health_check import AiHealthCheck

logger = logging.getLogger(__name__)

HEALTH_CHECK_IMAGE_RETENTION_DAYS = 30
```
- [ ] **Step 2: 프리미엄 기반 정리 함수 2개 삭제** — old (L16–L73 블록 전체):
```python
async def get_cleanup_candidates(db: AsyncSession) -> list[UserTier]:
    """프리미엄 만료 후 90일이 경과하고 아직 정리되지 않은 유저를 반환한다."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=IMAGE_RETENTION_DAYS)
    result = await db.execute(
        select(UserTier).where(
            UserTier.tier == "free",
            UserTier.premium_expires_at != None,  # noqa: E711
            UserTier.premium_expires_at < cutoff,
            UserTier.image_cleanup_completed_at == None,  # noqa: E711
        )
    )
    return list(result.scalars().all())


async def process_cleanups(db: AsyncSession, batch_size: int = 50) -> int:
    """이미지 정리 대상 유저의 건강체크 이미지를 일괄 삭제한다."""
    from app.models.pet import Pet
    from app.utils.file_storage import delete_upload_file

    candidates = await get_cleanup_candidates(db)
    if not candidates:
        return 0

    processed = 0
    for tier in candidates[:batch_size]:
        try:
            pet_result = await db.execute(
                select(Pet.id).where(Pet.user_id == tier.user_id)
            )
            pet_ids = [row[0] for row in pet_result.all()]

            if pet_ids:
                check_result = await db.execute(
                    select(AiHealthCheck).where(
                        AiHealthCheck.pet_id.in_(pet_ids),
                        AiHealthCheck.image_url != None,  # noqa: E711
                    )
                )
                checks = list(check_result.scalars().all())

                for check in checks:
                    try:
                        delete_upload_file(check.image_url)
                    except Exception as e:
                        logger.warning(
                            f"Failed to delete file {check.image_url} "
                            f"for user {tier.user_id}: {e}"
                        )
                    check.image_url = None

            tier.image_cleanup_completed_at = datetime.now(timezone.utc)
            processed += 1
            logger.info(f"Image cleanup completed for user {tier.user_id}")
        except Exception as e:
            logger.error(f"Image cleanup failed for user {tier.user_id}: {e}")

    await db.commit()
    return processed


```
new: (블록 전체 삭제 — 파일은 헤더 다음 바로 `cleanup_expired_health_check_images`로 이어짐)
- [ ] **Step 3: scheduler.py 잡 축소** — old:
```python
async def daily_image_cleanup_job():
    """매일 03:00 UTC에 실행: 만료된 프리미엄 사용자의 이미지 + 30일 초과 건강체크 이미지를 정리한다."""
    from app.database import async_session_factory
    from app.services.image_cleanup_service import process_cleanups, cleanup_expired_health_check_images

    logger.info("Starting daily image cleanup job")
    try:
        async with async_session_factory() as db:
            count = await process_cleanups(db)
            logger.info(f"Image cleanup job completed: {count} users processed")
    except Exception as e:
        logger.error(f"Image cleanup job failed: {e}", exc_info=True)

    try:
        async with async_session_factory() as db:
            expired = await cleanup_expired_health_check_images(db)
            logger.info(f"Health check image cleanup completed: {expired} expired images deleted")
    except Exception as e:
        logger.error(f"Health check image cleanup failed: {e}", exc_info=True)
```
new:
```python
async def daily_image_cleanup_job():
    """매일 03:00 UTC에 실행: 30일 초과 건강체크 이미지를 정리한다 (전체 사용자 동일 보존 정책)."""
    from app.database import async_session_factory
    from app.services.image_cleanup_service import cleanup_expired_health_check_images

    logger.info("Starting daily image cleanup job")
    try:
        async with async_session_factory() as db:
            expired = await cleanup_expired_health_check_images(db)
            logger.info(f"Health check image cleanup completed: {expired} expired images deleted")
    except Exception as e:
        logger.error(f"Health check image cleanup failed: {e}", exc_info=True)
```
- [ ] **Step 4: 검증 루프** — Run: `cd /Users/imdonghyeon/perch_care/backend && python3 -m compileall app -q && python3 -c "import app.main" && python3 -m pytest app/tests -q` → 기대: exit 0 + `47 passed`. 추가 확인: `grep -rn "process_cleanups\|get_cleanup_candidates\|IMAGE_RETENTION_DAYS " app/ --include="*.py" | grep -v __pycache__` → 매치 0건. 실패 시 수정 후 재실행 반복 → 통과 후 커밋:
```
cd /Users/imdonghyeon/perch_care && git add backend/app/services/image_cleanup_service.py backend/app/scheduler.py && git commit -m "|REMOVE| 이미지 정리 프리미엄 만료 90일 기준 제거 — 전원 30일 동일 보존

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
```

---

### Task 6.8: UserTier·PremiumCode 모델 파일 삭제 (DB 테이블 보존) + 최종 스윕
> **선행 조건**: 6.2/6.4/6.6/6.7로 코드 참조 소멸. 남은 참조는 `models/__init__.py`와 `models/user.py`의 `tier_info` relationship뿐 — **relationship을 먼저 제거하지 않으면 SQLAlchemy mapper 구성 시점에 `UserTier` 미해결로 런타임 크래시**하므로 파일 삭제 전에 제거한다. `user_tiers`/`premium_codes`/`subscription_transactions` DB 테이블은 보존 — drop 마이그레이션 금지, `alembic/` 불변 (모델을 metadata에서 빼도 `create_all`은 기존 테이블을 건드리지 않음). `models/subscription_transaction.py`는 (g) 범위 밖이라 유지(orphan — 노트 참조).

**Files:**
- Modify: `/Users/imdonghyeon/perch_care/backend/app/models/user.py` (L23)
- Modify: `/Users/imdonghyeon/perch_care/backend/app/models/__init__.py` (L14–L15, L27)
- Delete: `/Users/imdonghyeon/perch_care/backend/app/models/user_tier.py`, `/Users/imdonghyeon/perch_care/backend/app/models/premium_code.py`
**Interfaces:** Consumes: Task 6.2, 6.4, 6.6, 6.7 완료. Produces: 없음 (제거 전용).

- [ ] **Step 1: user.py에서 tier_info relationship 제거** — old:
```python
    pets = relationship("Pet", back_populates="user", cascade="all, delete-orphan")
    notifications = relationship("Notification", back_populates="user", cascade="all, delete-orphan")
    social_accounts = relationship("SocialAccount", back_populates="user", cascade="all, delete-orphan")
    tier_info = relationship("UserTier", back_populates="user", uselist=False, cascade="all, delete-orphan")
```
new:
```python
    pets = relationship("Pet", back_populates="user", cascade="all, delete-orphan")
    notifications = relationship("Notification", back_populates="user", cascade="all, delete-orphan")
    social_accounts = relationship("SocialAccount", back_populates="user", cascade="all, delete-orphan")
```
- [ ] **Step 2: models/__init__.py에서 import 제거** — old:
```python
from app.models.device_token import DeviceToken
from app.models.user_tier import UserTier
from app.models.premium_code import PremiumCode
from app.models.ai_vision_log import AiVisionLog
```
new:
```python
from app.models.device_token import DeviceToken
from app.models.ai_vision_log import AiVisionLog
```
- [ ] **Step 3: models/__init__.py `__all__` 정리** — old:
```python
__all__ = ["Base", "User", "Pet", "WeightRecord", "DailyRecord", "FoodRecord", "WaterRecord", "AiHealthCheck", "Schedule", "Notification", "SocialAccount", "AiEncyclopediaLog", "DeviceToken", "UserTier", "PremiumCode", "AiVisionLog", "AiChatSession", "AiChatMessage", "PetInsight", "BreedStandard", "PasswordResetCode", "DemoUsageLog"]
```
new:
```python
__all__ = ["Base", "User", "Pet", "WeightRecord", "DailyRecord", "FoodRecord", "WaterRecord", "AiHealthCheck", "Schedule", "Notification", "SocialAccount", "AiEncyclopediaLog", "DeviceToken", "AiVisionLog", "AiChatSession", "AiChatMessage", "PetInsight", "BreedStandard", "PasswordResetCode", "DemoUsageLog"]
```
- [ ] **Step 4: 모델 파일 삭제** — Run:
```
cd /Users/imdonghyeon/perch_care && git rm backend/app/models/user_tier.py backend/app/models/premium_code.py
```
- [ ] **Step 5: mapper 구성 강제 검증** (dangling relationship 탐지 — import만으로는 lazy 구성이라 안 잡힘) — Run: `cd /Users/imdonghyeon/perch_care/backend && python3 -c "import app.models; from sqlalchemy.orm import configure_mappers; configure_mappers(); print('mappers OK')"` → 기대: `mappers OK`.
- [ ] **Step 6: 최종 프리미엄 참조 스윕** — Run: `cd /Users/imdonghyeon/perch_care/backend && grep -rn "UserTier\|PremiumCode\|user_tier\|premium_code" app/ --include="*.py" | grep -v __pycache__` → 기대: 매치 0건. 이어서 `grep -rln "premium\|Premium" app/ --include="*.py" | grep -v __pycache__` → 기대 잔존은 코스메틱뿐: `app/services/ai_service.py`(`_get_premium_format` — 전 사용자 공통 프롬프트 포맷 함수명·주석, 기능 변화 없음)과 `app/schemas/health_summary.py`/`app/services/deepseek_service.py`의 주석 수준. 그 외 파일이 잡히면 원인 확인 후 제거.
- [ ] **Step 7: 검증 루프** — Run: `cd /Users/imdonghyeon/perch_care/backend && python3 -m compileall app -q && python3 -c "import app.main" && python3 -c "import app.jobs.weekly_insights" && python3 -m pytest app/tests -q` → 기대: exit 0 + `47 passed`. 실패 시 수정 후 재실행 반복 → 통과 후 커밋:
```
cd /Users/imdonghyeon/perch_care && git add backend/app/models/user.py backend/app/models/__init__.py && git commit -m "|REMOVE| UserTier·PremiumCode 모델 파일 삭제 — DB 테이블은 보존(drop 마이그레이션 없음)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
```

---

### Slice 6 잔여 노트 (태스크 외)
- **배포**: 범위 밖 — 사용자가 Railway로 백엔드 먼저 배포 후 앱 릴리즈 (스펙 1-D 배포 순서). 백엔드는 staging 환경임에 유의, Railway 환경변수는 절대 변경하지 않는다.
- **admin.html**: `app/templates/admin.html`은 삭제된 `/api/v1/premium/admin/*` API에 전면 의존(프리미엄 코드 발급/사용자 tier 관리 대시보드) — 6.4 이후 동작 불가. 삭제/축소 여부는 스펙 범위 밖이므로 사용자 결정 필요.
- **orphan 유지 파일**: `models/subscription_transaction.py`(소비처 소멸, (g) 범위 밖), `ai_service.py`의 dead `tier` 기본 파라미터들(`_select_model`·`_build_rag_context` 등 — 내부적으로 tier 미사용 확인, 슬라이스 범위 밖) — 후속 정리 후보.
- **진행 전 확인 (스펙 리스크 표)**: `user_tiers`/`premium_codes` 테이블에 활성 프리미엄/프로모 사용자가 있는지 사용자가 수동 확인 후 진행 권장.

---

## 슬라이스 5 — l10n · 부수 파일 · 의존성 정리

### Task 5.1: 중립 쿼터 한도 l10n 키 신설 (최선행 — 슬라이스 2·3 착수 전 완료 필수)
**Files:**
- Modify: `lib/l10n/app_ko.arb` (1193-1196행)
- Modify: `lib/l10n/app_en.arb` (995-998행 부근, 파일 끝)
- Modify: `lib/l10n/app_zh.arb` (1162-1165행 부근, 파일 끝)
- Modify(재생성): `lib/l10n/app_localizations.dart`, `app_localizations_ko.dart`, `app_localizations_en.dart`, `app_localizations_zh.dart` (`flutter gen-l10n` 산출물)

**Interfaces:** Produces — `AppLocalizations.quota_limitReachedTitle` (String getter), `AppLocalizations.quota_limitReachedMessage` (String getter). 슬라이스 2(health_check 403 처리)·슬라이스 3(ai_encyclopedia 429 처리)의 교체 코드가 이 getter를 참조한다.

- [ ] **Step 1: app_ko.arb 끝에 키 2종 추가.** 파일 끝(1193-1196행)을 다음과 같이 교체:
  old:
  ```json
    "hc_analysisTimeout": "분석 시간이 너무 오래 걸려요. 네트워크를 확인하고 다시 시도해주세요.",

    "common_defaultPetName": "사랑이"
  }
  ```
  new:
  ```json
    "hc_analysisTimeout": "분석 시간이 너무 오래 걸려요. 네트워크를 확인하고 다시 시도해주세요.",

    "quota_limitReachedTitle": "사용 한도 도달",
    "quota_limitReachedMessage": "이번 달 사용 한도에 도달했어요. 다음 달에 다시 이용할 수 있어요.",

    "common_defaultPetName": "사랑이"
  }
  ```
- [ ] **Step 2: app_en.arb 끝에 동일 키 추가.**
  old:
  ```json
    "hc_analysisTimeout": "The analysis is taking too long. Please check your connection and try again.",

    "common_defaultPetName": "Buddy"
  }
  ```
  new:
  ```json
    "hc_analysisTimeout": "The analysis is taking too long. Please check your connection and try again.",

    "quota_limitReachedTitle": "Limit Reached",
    "quota_limitReachedMessage": "You've reached this month's usage limit. It resets next month.",

    "common_defaultPetName": "Buddy"
  }
  ```
- [ ] **Step 3: app_zh.arb 끝에 동일 키 추가.**
  old:
  ```json
    "hc_analysisTimeout": "分析耗时过长。请检查网络后重试。",

    "common_defaultPetName": "宝贝"
  }
  ```
  new:
  ```json
    "hc_analysisTimeout": "分析耗时过长。请检查网络后重试。",

    "quota_limitReachedTitle": "已达使用上限",
    "quota_limitReachedMessage": "本月使用次数已达上限，下月将重置。",

    "common_defaultPetName": "宝贝"
  }
  ```
- [ ] **Step 4: JSON 유효성 확인.** Run: `python3 -c "import json;[json.load(open(f)) for f in ['lib/l10n/app_ko.arb','lib/l10n/app_en.arb','lib/l10n/app_zh.arb']];print('OK')"` → `OK` 출력 확인. 실패 시 쉼표/따옴표 수정 후 재실행.
- [ ] **Step 5: gen-l10n 재생성.** Run: `flutter gen-l10n` → 에러 없이 종료(untranslated 경고 0). `grep -n "quota_limitReachedTitle" lib/l10n/app_localizations_ko.dart`로 getter 생성 확인.
- [ ] **Step 6: 검증 루프 + 커밋.** Run: `flutter analyze` → 실패 시 원인 수정 후 재실행, 통과할 때까지 반복(기대: 신규 이슈 0). 통과 후:
  ```
  git add lib/l10n/app_ko.arb lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_ko.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_zh.dart
  git commit -m "|I18N| 쿼터 한도 중립 안내 키 신설 — quota_limitReachedTitle/Message (ko/en/zh)

  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
  ```

---

### Task 5.2: faq_screen 프리미엄 FAQ 카테고리 제거
**Files:**
- Modify: `lib/src/screens/faq/faq_screen.dart` (34-41행)

**Interfaces:** 없음 (Task 5.7이 이 태스크 완료를 전제로 `faq_categoryPremium`/`faq_q14~a16` 키를 arb에서 제거)

- [ ] **Step 1: 프리미엄 카테고리 블록 제거.**
  old:
  ```dart
        _FaqCategory(
          title: l10n.faq_categoryPremium,
          items: [
            _FaqItem(question: l10n.faq_q14, answer: l10n.faq_a14),
            _FaqItem(question: l10n.faq_q15, answer: l10n.faq_a15),
            _FaqItem(question: l10n.faq_q16, answer: l10n.faq_a16),
          ],
        ),
        _FaqCategory(
          title: l10n.faq_categoryUsage,
  ```
  new:
  ```dart
        _FaqCategory(
          title: l10n.faq_categoryUsage,
  ```
- [ ] **Step 2: 잔존 참조 확인.** Run: `grep -n "faq_categoryPremium\|faq_q14\|faq_q15\|faq_q16\|faq_a14\|faq_a15\|faq_a16" lib/src -r` → 0건 확인.
- [ ] **Step 3: 검증 루프 + 커밋.** Run: `flutter analyze` → 실패 시 원인 수정 후 재실행, 통과할 때까지 반복(기대: 신규 이슈 0). 통과 후:
  ```
  git add lib/src/screens/faq/faq_screen.dart
  git commit -m "|REMOVE| FAQ 프리미엄 카테고리(q14-16) 제거

  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
  ```

---

### Task 5.3: terms_content 약관 프리미엄 조항 정리 (ko/en/zh)
**Files:**
- Modify: `lib/src/data/terms_content.dart` (ko ToS 66-102행 / ko 개인정보 154-175행 / en ToS 252-288행 / en 개인정보 340-361행 / zh ToS 438-474행 / zh 개인정보 526-547행)

**Interfaces:** 없음. 주의: 개인정보처리방침의 일반 마케팅 동의("이벤트, 프로모션 정보 제공" — 602·633행 부근 `_marketingKo`/`_marketingEn`/`_marketingZh`)는 **수정하지 않는다**. 이미지 보존 정책은 "프리미엄 만료 후 90일" → "업로드 후 90일"(전원 동일)로 통일한다 (backend image_cleanup_service 단순화와 일치).

- [ ] **Step 1: ko 이용약관 — 제4-2조 삭제.**
  old:
  ```
  제4-2조 (프리미엄 서비스)
  ① 프리미엄 서비스는 프로모션 코드를 통해 이용할 수 있습니다.
  ② 프리미엄 전용 기능에는 AI 비전 건강체크 무제한 이용이 포함됩니다.
  ③ 프리미엄 코드의 유효기간 만료 시, 자동으로 무료 플랜으로 전환됩니다.
  ④ 프리미엄 만료 후 90일이 경과하면, 서버에 저장된 건강체크 이미지가 자동 삭제됩니다. 건강체크 텍스트 결과는 유지됩니다.
  ⑤ 이미지 삭제 전 앱 내 알림을 통해 사전 안내합니다.

  제5조 (서비스의 중단)
  ```
  new:
  ```
  제5조 (서비스의 중단)
  ```
- [ ] **Step 2: ko 이용약관 제9조 ⑤ — 이미지 보존 기준 중립화.**
  old:
  ```
  ⑤ AI 비전 분석을 위해 업로드된 이미지는 분석 및 기록 보관 목적으로 사용되며, 프리미엄 만료 후 90일 경과 시 자동 삭제됩니다.
  ```
  new:
  ```
  ⑤ AI 비전 분석을 위해 업로드된 이미지는 분석 및 기록 보관 목적으로 사용되며, 업로드 후 90일 경과 시 자동 삭제됩니다.
  ```
- [ ] **Step 3: ko 개인정보 — 수집 항목에서 프리미엄 구독 정보 삭제 + 항목 재부여.**
  old:
  ```
  마. 건강체크 이미지
   - AI 건강 분석을 위해 업로드한 반려동물 사진
   - 프리미엄 만료 후 90일 보관 후 자동 삭제

  바. AI 대화 기록
   - 챗봇 대화 내용 (세션별 저장)
   - 회원 탈퇴 시 즉시 삭제

  사. 프리미엄 구독 정보
   - 구독 상태, 프리미엄 코드, 만료 일자

  아. 기기 로컬 저장 정보
  ```
  new:
  ```
  마. 건강체크 이미지
   - AI 건강 분석을 위해 업로드한 반려동물 사진
   - 업로드 후 90일 보관 후 자동 삭제

  바. AI 대화 기록
   - 챗봇 대화 내용 (세션별 저장)
   - 회원 탈퇴 시 즉시 삭제

  사. 기기 로컬 저장 정보
  ```
- [ ] **Step 4: ko 개인정보 — 보유 기간 항목 정리.**
  old:
  ```
   - 건강체크 이미지: 프리미엄 만료 후 90일
   - AI 대화 기록: 회원 탈퇴 시까지
   - 프리미엄 구독 정보: 구독 종료 후 1년
   - 관계 법령에 의한 보존: 해당 법령이 정한 기간
  ```
  new:
  ```
   - 건강체크 이미지: 업로드 후 90일
   - AI 대화 기록: 회원 탈퇴 시까지
   - 관계 법령에 의한 보존: 해당 법령이 정한 기간
  ```
- [ ] **Step 5: en ToS — Article 4-2 삭제 + Article 9 #5 중립화.**
  old:
  ```
  Article 4-2 (Premium Service)
  1. Premium service can be accessed through promotional codes.
  2. Premium-exclusive features include unlimited AI Vision Health Check usage.
  3. Upon expiration of the premium code, the account automatically reverts to the free plan.
  4. Health check images stored on the server are automatically deleted 90 days after premium expiration. Health check text results are retained.
  5. Users will be notified via in-app notification before image deletion.

  Article 5 (Service Interruption)
  ```
  new:
  ```
  Article 5 (Service Interruption)
  ```
  old:
  ```
  5. Images uploaded for AI vision analysis are used for analysis and record-keeping purposes and are automatically deleted 90 days after premium expiration.
  ```
  new:
  ```
  5. Images uploaded for AI vision analysis are used for analysis and record-keeping purposes and are automatically deleted 90 days after upload.
  ```
- [ ] **Step 6: en 개인정보 — 수집 항목 g 삭제 + 보유 기간 정리.**
  old:
  ```
  e. Health Check Images
   - Pet photos uploaded for AI health analysis
   - Automatically deleted 90 days after premium expiration

  f. AI Chat History
   - Chatbot conversation content (stored per session)
   - Immediately deleted upon account withdrawal

  g. Premium Subscription Information
   - Subscription status, premium code, expiration date

  h. Device Local Storage Information
  ```
  new:
  ```
  e. Health Check Images
   - Pet photos uploaded for AI health analysis
   - Automatically deleted 90 days after upload

  f. AI Chat History
   - Chatbot conversation content (stored per session)
   - Immediately deleted upon account withdrawal

  g. Device Local Storage Information
  ```
  old:
  ```
   - Health check images: 90 days after premium expiration
   - AI chat history: Until membership withdrawal
   - Premium subscription information: 1 year after subscription ends
   - Retention under applicable laws: For the period prescribed by the relevant law
  ```
  new:
  ```
   - Health check images: 90 days after upload
   - AI chat history: Until membership withdrawal
   - Retention under applicable laws: For the period prescribed by the relevant law
  ```
- [ ] **Step 7: zh ToS — 第四-二条 삭제 + 第九条 ⑤ 중립화.**
  old:
  ```
  第四-二条（高级版服务）
  ① 高级版服务可通过促销代码使用。
  ② 高级版专属功能包括AI视觉健康检查无限使用。
  ③ 高级版代码有效期届满后，自动转为免费方案。
  ④ 高级版到期90天后，服务器上存储的健康检查图片将自动删除。健康检查文字结果将予以保留。
  ⑤ 图片删除前，将通过应用内通知提前告知。

  第五条（服务的中断）
  ```
  new:
  ```
  第五条（服务的中断）
  ```
  old:
  ```
  ⑤ 为AI视觉分析上传的图片用于分析及记录保管目的，高级版到期90天后自动删除。
  ```
  new:
  ```
  ⑤ 为AI视觉分析上传的图片用于分析及记录保管目的，上传90天后自动删除。
  ```
- [ ] **Step 8: zh 개인정보 — 항목 七 삭제 + 보유 기간 정리.**
  old:
  ```
  五、健康检查图片
   - 为AI健康分析上传的宠物照片
   - 高级版到期90天后自动删除

  六、AI对话记录
   - 聊天机器人对话内容（按会话存储）
   - 注销会员时立即删除

  七、高级版订阅信息
   - 订阅状态、高级版代码、到期日期

  八、设备本地存储信息
  ```
  new:
  ```
  五、健康检查图片
   - 为AI健康分析上传的宠物照片
   - 上传90天后自动删除

  六、AI对话记录
   - 聊天机器人对话内容（按会话存储）
   - 注销会员时立即删除

  七、设备本地存储信息
  ```
  old:
  ```
   - 健康检查图片：高级版到期后90天
   - AI对话记录：至会员注销时
   - 高级版订阅信息：订阅结束后1年
   - 依据相关法律保留：相关法律规定的期限
  ```
  new:
  ```
   - 健康检查图片：上传后90天
   - AI对话记录：至会员注销时
   - 依据相关法律保留：相关法律规定的期限
  ```
- [ ] **Step 9: 잔존 확인.** Run: `grep -n "프리미엄\|Premium\|高级版" lib/src/data/terms_content.dart` → 0건 확인 (마케팅 동의 섹션의 "이벤트, 프로모션 정보 제공"류 일반 문구는 매치되지 않음이 정상).
- [ ] **Step 10: 검증 루프 + 커밋.** Run: `flutter analyze` → 실패 시 원인 수정 후 재실행, 통과할 때까지 반복(기대: 신규 이슈 0). 통과 후:
  ```
  git add lib/src/data/terms_content.dart
  git commit -m "|REMOVE| 약관·개인정보처리방침 프리미엄 조항 정리 — 이미지 보존은 업로드 후 90일로 통일 (ko/en/zh)

  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
  ```

---

### Task 5.4: icons.dart workspacePremium 제거
**Files:**
- Modify: `lib/src/theme/icons.dart` (110-111행)

**Interfaces:** 없음 (사용처 0건 확인됨 — `grep -rn workspacePremium lib` 결과 icons.dart 자신뿐)

- [ ] **Step 1: 사용처 재확인.** Run: `grep -rn "workspacePremium" lib --include="*.dart"` → `lib/src/theme/icons.dart` 1건만 출력되는지 확인. 다른 파일이 나오면 해당 슬라이스 완료 전이므로 중단하고 대기.
- [ ] **Step 2: 상수 제거 + 섹션 헤더 정리.**
  old:
  ```dart
    // ── Premium & Account ───────────────────────────────────────
    static const IconData workspacePremium = Icons.workspace_premium;
    static const IconData lockOutline = Icons.lock_outline;
  ```
  new:
  ```dart
    // ── Account ─────────────────────────────────────────────────
    static const IconData lockOutline = Icons.lock_outline;
  ```
- [ ] **Step 3: 검증 루프 + 커밋.** Run: `flutter analyze` → 실패 시 원인 수정 후 재실행, 통과할 때까지 반복(기대: 신규 이슈 0). 통과 후:
  ```
  git add lib/src/theme/icons.dart
  git commit -m "|REMOVE| workspacePremium 아이콘 상수 제거

  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
  ```

---

### Task 5.5: coach_mark_service screenPremium 상수 제거 (선행: 슬라이스 1의 premium_screen.dart 삭제)
**Files:**
- Modify: `lib/src/services/coach_mark/coach_mark_service.dart` (21행)

**Interfaces:** 없음. **선행 조건**: `lib/src/screens/premium/premium_screen.dart` 삭제 완료 (현재 91·116행에서 `CoachMarkService.screenPremium` 참조 — 참조 제거가 상수 제거보다 먼저).

- [ ] **Step 1: 선행 조건 확인.** Run: `ls lib/src/screens/premium/ 2>/dev/null; grep -rn "screenPremium" lib --include="*.dart" | grep -v coach_mark_service` → 둘 다 0건이어야 진행. 남아 있으면 슬라이스 1 완료 대기.
- [ ] **Step 2: 상수 제거.**
  old:
  ```dart
    static const String screenProfile = 'profile';
    static const String screenPremium = 'premium';
    static const String screenPetProfileDetail = 'pet_profile_detail';
  ```
  new:
  ```dart
    static const String screenProfile = 'profile';
    static const String screenPetProfileDetail = 'pet_profile_detail';
  ```
- [ ] **Step 3: 검증 루프 + 커밋.** Run: `flutter analyze` → 실패 시 원인 수정 후 재실행, 통과할 때까지 반복(기대: 신규 이슈 0). 통과 후:
  ```
  git add lib/src/services/coach_mark/coach_mark_service.dart
  git commit -m "|REMOVE| CoachMarkService screenPremium 상수 제거

  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
  ```

---

### Task 5.6: analytics_service 프리미엄/paywall/쿼터 이벤트 메서드 제거 (선행: 슬라이스 1·2·3의 호출처 제거)
**Files:**
- Modify: `lib/src/services/analytics/analytics_service.dart` (52-119행)

**Interfaces:** 없음. **선행 조건 (호출처가 먼저 제거돼야 함)**:
- 슬라이스 1 파일 삭제: `premium_screen.dart` (logPaywallView·logCheckoutStarted·logPromoCodeEntryOpened·logPlanSelected), `promo_code_bottom_sheet.dart` (logPromoCodeActivated), `iap_service.dart` (logPurchaseSuccess·logPurchaseFailed·logRestoreSuccess)
- 슬라이스 2: `health_check_main_screen.dart:211` (logPremiumFeatureBlocked), `health_check_analyzing_screen.dart:140` (logVisionTrialUsed)
- 슬라이스 3: `ai_encyclopedia_screen.dart:136` (logQuotaViewed), `:323`·`:519` (logQuotaReached), `:1142` (logPremiumFeatureBlocked)

- [ ] **Step 1: 호출처 0건 확인.** Run: `grep -rn "logPaywallView\|logPlanSelected\|logCheckoutStarted\|logPurchaseSuccess\|logPurchaseFailed\|logRestoreSuccess\|logPremiumFeatureBlocked\|logPromoCodeEntryOpened\|logPromoCodeActivated\|logQuotaViewed\|logQuotaReached\|logVisionTrialUsed" lib test --include="*.dart" | grep -v analytics_service.dart` → 0건이어야 진행. 남아 있으면 해당 슬라이스 완료 대기.
- [ ] **Step 2: 이벤트 메서드 블록(52-119행) 삭제.**
  old:
  ```dart
    // --- IAP / Paywall Events ---

    Future<void> logPaywallView({required String source, String? feature}) =>
        _analytics.logEvent(name: 'paywall_view', parameters: {
          'source': source,
          if (feature != null) 'feature': feature,
        });

    Future<void> logPlanSelected({required String plan, required String source}) =>
        _analytics.logEvent(name: 'plan_selected', parameters: {
          'plan': plan,
          'source': source,
        });

    Future<void> logCheckoutStarted({required String store, required String productId, required String source}) =>
        _analytics.logEvent(name: 'checkout_started', parameters: {
          'store': store,
          'product_id': productId,
          'source': source,
        });

    Future<void> logPurchaseSuccess({required String store, required String productId, bool isRestore = false}) =>
        _analytics.logEvent(name: 'purchase_success', parameters: {
          'store': store,
          'product_id': productId,
          'is_restore': isRestore,
        });

    Future<void> logPurchaseFailed({required String store, required String productId, required String reason}) =>
        _analytics.logEvent(name: 'purchase_failed', parameters: {
          'store': store,
          'product_id': productId,
          'reason': reason,
        });

    Future<void> logRestoreSuccess({required String store}) =>
        _analytics.logEvent(name: 'restore_success', parameters: {'store': store});

    Future<void> logPremiumFeatureBlocked({required String feature, required String sourceScreen}) =>
        _analytics.logEvent(name: 'premium_feature_blocked', parameters: {
          'feature': feature,
          'source_screen': sourceScreen,
        });

    Future<void> logPromoCodeEntryOpened({required String source}) =>
        _analytics.logEvent(name: 'promo_code_entry_opened', parameters: {'source': source});

    Future<void> logPromoCodeActivated({required String codePrefix}) =>
        _analytics.logEvent(name: 'promo_code_activated', parameters: {'code_prefix': codePrefix});

    // --- Quota Events (Phase 2) ---

    Future<void> logQuotaViewed({required int remaining, required String tier}) =>
        _analytics.logEvent(name: 'ai_quota_viewed', parameters: {
          'remaining': remaining,
          'tier': tier,
        });

    Future<void> logQuotaReached({required String feature, required int usedCount}) =>
        _analytics.logEvent(name: 'ai_quota_reached', parameters: {
          'feature': feature,
          'used_count': usedCount,
        });

    Future<void> logVisionTrialUsed({required int remainingAfter}) =>
        _analytics.logEvent(name: 'vision_trial_used', parameters: {
          'remaining_after': remainingAfter,
        });

    // --- In-App Review ---
  ```
  new:
  ```dart
    // --- In-App Review ---
  ```
- [ ] **Step 3: 검증 루프 + 커밋.** Run: `flutter analyze` → 실패 시 원인 수정 후 재실행, 통과할 때까지 반복(기대: 신규 이슈 0). 통과 후:
  ```
  git add lib/src/services/analytics/analytics_service.dart
  git commit -m "|REMOVE| 프리미엄/paywall/쿼터 analytics 이벤트 메서드 제거

  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
  ```

---

### Task 5.7: arb 3파일 프리미엄 키 전수 제거 + gen-l10n (최후행 — 슬라이스 1~4 화면 수정·파일 삭제 및 Task 5.2 완료 후)
**Files:**
- Modify: `lib/l10n/app_ko.arb` (692-693, 714-715, 721-725, 822-828, 842-875, 1031-1108, 1124, 1128행)
- Modify: `lib/l10n/app_en.arb` (494-495, 516-517, 523-527, 624-630, 644-677, 833-910, 926, 930행)
- Modify: `lib/l10n/app_zh.arb` (661-662, 683-684, 690-694, 791-797, 811-844, 1000-1077, 1093, 1097행)
- Modify(재생성): `lib/l10n/app_localizations*.dart` 4종

**Interfaces:** Consumes — Task 5.1의 `quota_limitReachedTitle/Message`는 **삭제 대상이 아님** (grep 패턴에 안 걸리는지 확인). Produces — 없음.

**제거 키 전수 목록 (3파일 동일 세트 확인 완료, `@`는 placeholder 메타데이터 블록):**
- coach (8): `coach_hcTrial_title`, `coach_hcTrial_body`, `coach_profilePremium_title`, `coach_profilePremium_body`, `coach_premiumPlan_title`, `coach_premiumPlan_body`, `coach_premiumPromo_title`, `coach_premiumPromo_body`
- faq (7): `faq_categoryPremium`, `faq_q14`, `faq_a14`, `faq_q15`, `faq_a15`, `faq_q16`, `faq_a16`
- premium (27 + 메타 2): `premium_sectionTitle`, `premium_title`, `premium_badgeFree`, `premium_badgePremium`, `premium_expiresAt`, `@premium_expiresAt`, `premium_enterCode`, `premium_benefitsTitle`, `premium_benefit1`, `premium_benefit2`, `premium_benefit3`, `premium_codeInputTitle`, `premium_codeInputHint`, `premium_activateButton`, `premium_invalidCodeFormat`, `premium_activationFailed`, `premium_activationError`, `premium_rateLimitExceeded`, `premium_activationSuccessTitle`, `premium_activationSuccessContent`, `@premium_activationSuccessContent`, `premium_activationSuccessContentNoDate`, `premium_upgradeToPremium`, `premium_healthCheckBlocked`, `premium_healthCheckBlockedTitle`, `premium_featureLockedTitle`, `premium_featureLockedMessage`, `premium_activateNow`, `premium_maybeLater`
- chatbot (2): `chatbot_premiumBanner`, `chatbot_premiumUpgrade`
- paywall (27 + 메타 2): `paywall_title`, `paywall_headline`, `paywall_benefit1`, `paywall_benefit2`, `paywall_benefit3`, `paywall_planMonthly`, `paywall_planYearly`, `paywall_yearlyDiscount`, `paywall_yearlyPerMonth`, `@paywall_yearlyPerMonth`, `paywall_ctaButton`, `paywall_restore`, `paywall_promoCode`, `paywall_purchaseSuccessTitle`, `paywall_purchaseSuccessContent`, `paywall_purchaseFailed`, `paywall_restoreSuccess`, `paywall_restoreNoSubscription`, `paywall_restoreFailed`, `paywall_loading`, `paywall_storeUnavailable`, `paywall_productsNotFound`, `paywall_alreadyPremium`, `paywall_alreadyPremiumExpires`, `@paywall_alreadyPremiumExpires`, `paywall_freeTrialBanner`, `paywall_freeTrialSubtext`, `paywall_snsEventTitle`, `paywall_snsEventDescription`
- quotaBadge (3 + 메타 1): `quotaBadge_normal`, `@quotaBadge_normal`, `quotaBadge_exhausted`, `quotaBadge_upgrade`
- visionQuotaBadge (3 + 메타 1): `visionQuotaBadge_normal`, `@visionQuotaBadge_normal`, `visionQuotaBadge_exhausted`, `visionQuotaBadge_upgrade`
- 백과사전/건강체크 (7): `aiEncyclopedia_quotaExhausted`, `aiEncyclopedia_quotaExhaustedHint`, `healthCheck_freeTrialBadge`, `healthCheck_trialExhaustedTitle`, `healthCheck_trialExhaustedMessage`, `healthCheck_trialExhaustedMessage_v2`, `healthCheck_trialExhaustedAction_promo`
- sns (1 + 메타 1): `sns_copied`, `@sns_copied`
- home dead 키 (2 — 코드 참조 0건 확인됨): `home_healthSummaryUpgrade`, `home_insightsUpgrade`

**합계: 87키 + @메타데이터 7블록 × 3파일.**

- [ ] **Step 1: 선행 조건 확인 — 코드 참조 0건.** Run: `grep -rn "premium_\|paywall_\|quotaBadge_\|visionQuotaBadge_\|aiEncyclopedia_quotaExhausted\|trialExhausted\|freeTrialBadge\|chatbot_premium\|coach_hcTrial\|coach_premiumPlan\|coach_premiumPromo\|coach_profilePremium\|faq_categoryPremium\|faq_q1[456]\|faq_a1[456]\|sns_copied\|healthSummaryUpgrade\|insightsUpgrade" lib/src test --include="*.dart"` → 0건이어야 진행. hit이 나오면 해당 슬라이스(1: premium/iap/quota_badge/sns_event_card 삭제, 2: health_check 5화면, 3: ai_encyclopedia, 4: home 도메인) 완료 대기.
- [ ] **Step 2: app_ko.arb 블록 삭제 (아래→위 순서로 라인 번호 어긋남 방지).** 삭제 범위(현재 라인 기준): 1128행(`home_insightsUpgrade`), 1124행(`home_healthSummaryUpgrade`), 1031-1108행(`premium_featureLockedTitle`~`@sns_copied` 닫는 `},` + 후행 공백줄), 842-875행(`premium_sectionTitle`~`premium_healthCheckBlockedTitle` + 후행 공백줄), 822-828행(faq 7키), 721-725행(coach_premiumPlan/Promo 4키 + 후행 공백줄), 714-715행(coach_profilePremium 2키), 692-693행(coach_hcTrial 2키). 각 블록의 첫/끝 키가 위 전수 목록과 일치하는지 삭제 전 확인.
- [ ] **Step 3: app_en.arb 블록 삭제 (아래→위).** 930행(`home_insightsUpgrade`), 926행(`home_healthSummaryUpgrade`), 833-910행(`premium_featureLockedTitle`~`@sns_copied` + 후행 공백줄 1개 — 이 파일은 공백줄 2개 연속이므로 1개만 남김), 644-677행(premium 메인 블록 + 후행 공백줄), 624-630행(faq), 523-527행(coach_premiumPlan/Promo + 공백줄), 516-517행(coach_profilePremium), 494-495행(coach_hcTrial).
- [ ] **Step 4: app_zh.arb 블록 삭제 (아래→위).** 1097행(`home_insightsUpgrade`), 1093행(`home_healthSummaryUpgrade`), 1000-1077행(`premium_featureLockedTitle`~`@sns_copied` + 후행 공백줄), 811-844행(premium 메인 블록 + 후행 공백줄), 791-797행(faq), 690-694행(coach_premiumPlan/Promo + 공백줄), 683-684행(coach_profilePremium), 661-662행(coach_hcTrial).
- [ ] **Step 5: 제거 완전성 + JSON 유효성 확인.** Run:
  ```
  grep -n '"\(premium_\|@premium_\|paywall_\|@paywall_\|quotaBadge_\|@quotaBadge_\|visionQuotaBadge_\|@visionQuotaBadge_\|aiEncyclopedia_quotaExhausted\|healthCheck_trialExhausted\|healthCheck_freeTrialBadge\|chatbot_premium\|coach_hcTrial\|coach_premiumPlan\|coach_premiumPromo\|coach_profilePremium\|faq_categoryPremium\|faq_[qa]1[456]\|sns_copied\|@sns_copied\|home_healthSummaryUpgrade\|home_insightsUpgrade\)' lib/l10n/app_*.arb
  ```
  → 0건. 그리고 `python3 -c "import json;[json.load(open(f)) for f in ['lib/l10n/app_ko.arb','lib/l10n/app_en.arb','lib/l10n/app_zh.arb']];print('OK')"` → `OK`. 또한 `quota_limitReachedTitle`이 3파일에 남아 있는지 확인: `grep -c quota_limitReached lib/l10n/app_*.arb` → 각 2.
- [ ] **Step 6: 3파일 키 세트 동일성 확인.** Run: `for f in ko en zh; do python3 -c "import json;print(sorted(k for k in json.load(open('lib/l10n/app_$f.arb')) if not k.startswith('@')))" | md5; done` → 3개 해시 동일.
- [ ] **Step 7: gen-l10n 재생성.** Run: `flutter gen-l10n` → 에러 0, untranslated 경고 0. `grep -c "premium_\|paywall_" lib/l10n/app_localizations.dart` → 0 확인.
- [ ] **Step 8: 검증 루프 + 커밋.** Run: `flutter analyze` → getter 미존재 에러가 나오면 잔존 참조 화면을 수정(해당 슬라이스 담당 코드가 덜 제거된 것 — 원인 수정) 후 재실행, 통과할 때까지 반복(기대: 이슈 0). 이어서 `flutter test` → 전체 통과. 통과 후:
  ```
  git add lib/l10n/app_ko.arb lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_ko.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_zh.dart
  git commit -m "|REMOVE| l10n 프리미엄·paywall·쿼터배지·SNS 이벤트 키 87종(+메타 7) 제거 (ko/en/zh) — gen-l10n 재생성

  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
  ```

---

### Task 5.8: in_app_purchase 의존성 + StoreKit 수동 링크 제거 (최후행 — iap_service.dart 삭제 후)
**Files:**
- Modify: `pubspec.yaml` (38행)
- Modify: `pubspec.lock` (`flutter pub get` 산출물)
- Modify: `ios/Runner.xcodeproj/project.pbxproj` (18, 69, 89, 169행)
- Modify: `ios/Podfile.lock` (`pod install` 산출물 — in_app_purchase_storekit 항목 제거됨)

**Interfaces:** 없음. **선행 조건**: `lib/src/services/iap/iap_service.dart` 삭제 완료(슬라이스 1) — 유일한 `in_app_purchase` import 파일.

- [ ] **Step 1: 선행 조건 확인.** Run: `grep -rn "in_app_purchase" lib --include="*.dart"` → 0건이어야 진행.
- [ ] **Step 2: pubspec.yaml에서 의존성 제거.**
  old:
  ```yaml
    in_app_review: ^2.0.10
    in_app_purchase: ^3.2.0
    share_plus: ^10.1.4
  ```
  new:
  ```yaml
    in_app_review: ^2.0.10
    share_plus: ^10.1.4
  ```
- [ ] **Step 3: 의존성 갱신.** Run: `flutter pub get` → `Got dependencies!` 출력, pubspec.lock에서 in_app_purchase 계열 제거 확인: `grep -c in_app_purchase pubspec.lock` → 0.
- [ ] **Step 4: pbxproj — PBXBuildFile 항목(18행) 제거.**
  old:
  ```
  		97C147011CF9000F007C117D /* LaunchScreen.storyboard in Resources */ = {isa = PBXBuildFile; fileRef = 97C146FF1CF9000F007C117D /* LaunchScreen.storyboard */; };
  		AEA366DF2F5C515C00139D11 /* StoreKit.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = AEA366DE2F5C515C00139D11 /* StoreKit.framework */; };
  ```
  new:
  ```
  		97C147011CF9000F007C117D /* LaunchScreen.storyboard in Resources */ = {isa = PBXBuildFile; fileRef = 97C146FF1CF9000F007C117D /* LaunchScreen.storyboard */; };
  ```
- [ ] **Step 5: pbxproj — PBXFileReference 항목(69행) 제거.**
  old:
  ```
  		AE5D6DB92F2B4E0800503BCE /* Runner.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = Runner.entitlements; sourceTree = "<group>"; };
  		AEA366DE2F5C515C00139D11 /* StoreKit.framework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = StoreKit.framework; path = System/Library/Frameworks/StoreKit.framework; sourceTree = SDKROOT; };
  ```
  new:
  ```
  		AE5D6DB92F2B4E0800503BCE /* Runner.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = Runner.entitlements; sourceTree = "<group>"; };
  ```
- [ ] **Step 6: pbxproj — Frameworks build phase(89행) 제거.**
  old:
  ```
  			files = (
  				AF02E1B1F2A2650101199DDB /* Pods_Runner.framework in Frameworks */,
  				AEA366DF2F5C515C00139D11 /* StoreKit.framework in Frameworks */,
  			);
  ```
  new:
  ```
  			files = (
  				AF02E1B1F2A2650101199DDB /* Pods_Runner.framework in Frameworks */,
  			);
  ```
- [ ] **Step 7: pbxproj — Frameworks group children(169행) 제거.**
  old:
  ```
  			children = (
  				AEA366DE2F5C515C00139D11 /* StoreKit.framework */,
  				249DC12C8C6765AFB13F8586 /* Pods_Runner.framework */,
  				ACF77CE08EF8A43FBAD1C4AE /* Pods_RunnerTests.framework */,
  			);
  ```
  new:
  ```
  			children = (
  				249DC12C8C6765AFB13F8586 /* Pods_Runner.framework */,
  				ACF77CE08EF8A43FBAD1C4AE /* Pods_RunnerTests.framework */,
  			);
  ```
  확인: `grep -c "AEA366D\|StoreKit" ios/Runner.xcodeproj/project.pbxproj` → 0.
- [ ] **Step 8: iOS pod 갱신.** Run: `cd ios && pod install && cd ..` → 완료 후 `grep -c in_app_purchase ios/Podfile.lock` → 0. (macos/Podfile.lock에는 in_app_purchase 항목이 원래 없음 — 변경 불필요.)
- [ ] **Step 9: 검증 루프 + 커밋.** Run: `flutter analyze` → 통과할 때까지 원인 수정 후 재실행. 이어서 `flutter build ios --no-codesign` → `✓ Built build/ios/iphoneos/Runner.app` 출력(StoreKit 제거 상태 빌드 검증). 실패 시 pbxproj/Pods 원인 수정 후 재실행, 통과할 때까지 반복. 통과 후:
  ```
  git add pubspec.yaml pubspec.lock ios/Runner.xcodeproj/project.pbxproj ios/Podfile.lock
  git commit -m "|REMOVE| in_app_purchase 의존성 및 StoreKit.framework 수동 링크 제거

  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
  ```

---

### Task 5.9: 문서 갱신 — quota-system.md + CLAUDE.md (최후행)
**Files:**
- Modify: `docs/architecture/quota-system.md` (3-5, 10, 19, 21, 29-33, 57, 93-96행)
- Modify: `CLAUDE.md` (103, 147, 169-178, 228행) — **gitignored, git add 금지** (로컬 파일만 수정)

**Interfaces:** 없음

- [ ] **Step 1: quota-system.md 헤더 갱신.**
  old:
  ```markdown
  > Free 사용자의 AI 백과사전·Vision 월간 한도를 동시 요청 race 없이 정확히 차감하고, AI 실패 시 환원까지 보장하는 쿼터 시스템.
  >
  > **갱신** — 2026-05-13
  ```
  new:
  ```markdown
  > 전체 사용자의 AI 백과사전·Vision 월간 한도를 동시 요청 race 없이 정확히 차감하고, AI 실패 시 환원까지 보장하는 쿼터 시스템.
  >
  > **갱신** — 2026-07-05 (프리미엄 tier 전면 제거 — 전원 동일 free 한도 적용, 쿼터는 LLM 비용 안전장치로 유지)
  ```
- [ ] **Step 2: quota-system.md 설명·트러블슈팅 문장 갱신.**
  old:
  ```markdown
  Free 사용자에게 AI 월간 사용 한도를 부여해 LLM 비용을 통제하되, 동시 요청 상황에서도 한도가 정확히 지켜지고 AI 호출이 실패했을 때는 사용자가 쿼터를 손해 보지 않는 production-grade 쿼터 시스템을 설계·구현했다.
  ```
  new:
  ```markdown
  모든 사용자에게 AI 월간 사용 한도(백과사전 30회/비전 10회)를 부여해 LLM 비용을 통제하되, 동시 요청 상황에서도 한도가 정확히 지켜지고 AI 호출이 실패했을 때는 사용자가 쿼터를 손해 보지 않는 production-grade 쿼터 시스템을 설계·구현했다.
  ```
  old:
  ```markdown
  응답이 길어져도 동시 요청을 차단하지 않게 했다. Premium은 lock·예약 단계를 통째로 건너뛰어 contention 자체가 없다.
  ```
  new:
  ```markdown
  응답이 길어져도 동시 요청을 차단하지 않게 했다.
  ```
  old:
  ```markdown
  이 경로로 환원된다. `/premium/tier` 응답은 encyclopedia·vision 사용량을 단일 SELECT의 두 scalar subquery로 통합(`get_combined_free_usage_this_month`)해 AsyncSession의 `asyncio.gather` 동시성 제약을 회피하면서 round-trip을 줄였다. 월 경계 계산은 UTC 기준으로 통일.
  ```
  new:
  ```markdown
  이 경로로 환원된다. 월 경계 계산은 UTC 기준으로 통일. (프리미엄 tier 및 `/premium/tier` 엔드포인트는 2026-07 제거 — 전원 동일 free 한도 적용.)
  ```
- [ ] **Step 3: quota-system.md mermaid에서 premium 분기 제거.**
  old:
  ```
      Req["AI 요청<br/>(user_id, tier, query)"]

      T{"tier == premium?"}
      T -- "yes" --> Pass["lock/예약 skip<br/>(무제한)"]
      T -- "no" --> Lock["pg_advisory_xact_lock(ns, key)<br/>ns: enc=100 / vis=101"]
  ```
  new:
  ```
      Req["AI 요청<br/>(user_id, query)"]

      Req --> Lock["pg_advisory_xact_lock(ns, key)<br/>ns: enc=100 / vis=101"]
  ```
  old:
  ```
      class Pass,SyncOK,SseOK ok
  ```
  new:
  ```
      class SyncOK,SseOK ok
  ```
- [ ] **Step 4: quota-system.md 핵심 메시지에 tier 제거 항목 추가.**
  old:
  ```markdown
  - **Single source of truth** — 별도 quota 테이블 없이 사용량 로그를 카운터로 활용 → 분석 데이터와 항상 일치
  ```
  new:
  ```markdown
  - **Single source of truth** — 별도 quota 테이블 없이 사용량 로그를 카운터로 활용 → 분석 데이터와 항상 일치
  - **전원 동일 한도** — 프리미엄 tier 제거(2026-07) 후 모든 사용자에게 free 한도 적용(백과사전 30/비전 10). 클라이언트는 사전 차단 UI 없이 서버 429/403 수신 시에만 중립 메시지로 안내
  ```
- [ ] **Step 5: CLAUDE.md providers 목록·전환현황 표에서 premium 제거 (git add 금지).**
  old:
  ```markdown
    - **[bhi_provider.dart](lib/src/providers/bhi_provider.dart)** — Bird Health Index 계산
    - **[premium_provider.dart](lib/src/providers/premium_provider.dart)** — 프리미엄 상태 + 쿼터
    - **[locale_provider.dart](lib/src/providers/locale_provider.dart)** — 다국어 (ko/en/zh)
  ```
  new:
  ```markdown
    - **[bhi_provider.dart](lib/src/providers/bhi_provider.dart)** — Bird Health Index 계산
    - **[locale_provider.dart](lib/src/providers/locale_provider.dart)** — 다국어 (ko/en/zh)
  ```
  old:
  ```markdown
  | 그 외 (auth/health_check/ai_encyclopedia/bhi/premium 등) | 필요 시 점진 전환 | — | — |
  ```
  new:
  ```markdown
  | 그 외 (auth/health_check/ai_encyclopedia/bhi 등) | 필요 시 점진 전환 | — | — |
  ```
- [ ] **Step 6: CLAUDE.md Premium/IAP 섹션을 서버 쿼터 안내로 교체.**
  old:
  ```markdown
  ### Premium / IAP (App Store 3.1.1 freemium 피벗)
  프리미엄 기능은 **monthly quota** 모델로 제공됩니다 (App Store 3.1.1 리젝 대응으로 "premium upgrade" 게이팅 → "월간 한도" UX로 전환):

  - **[premium_service.dart](lib/src/services/premium/premium_service.dart)** — `EncyclopediaQuota`, `VisionQuota`, `PremiumStatus` 모델. `monthlyLimit == -1`이면 unlimited
  - **[iap_service.dart](lib/src/services/iap/iap_service.dart)** — `in_app_purchase` 패키지 래퍼. App Store / Play Store 결제 + 복원 처리
  - **[premium_provider.dart](lib/src/providers/premium_provider.dart)** — 위 서비스들의 Riverpod 노출
  - **[premium_screen.dart](lib/src/screens/premium/premium_screen.dart)** — 결제 진입점. 현 단계는 restore-only 모드 (3.1.1 대응)
  - **[quota_badge.dart](lib/src/widgets/quota_badge.dart)** — 백과사전/Vision 쿼터 표시 위젯 (업그레이드 CTA 제거됨)

  쿼터 한도 도달 시 다국어 메시지: `premium_healthCheckBlocked` ("이번 달 사용 한도에 도달했어요").
  ```
  new:
  ```markdown
  ### Quota (서버 월간 한도)
  프리미엄/IAP 기능은 2026-07에 앱에서 전면 제거되었습니다. 서버(backend/)는 LLM 비용 안전장치로 월간 쿼터를 계속 강제합니다 (백과사전 30회 초과 → 429, 비전 10회 초과 → 403 — 전원 동일 한도).

  - 클라이언트에는 사전 차단 UI(잠금 카드·쿼터 배지·업그레이드 유도)가 없습니다 — 한도 도달은 서버 429/403 응답 수신 시에만 안내합니다.
  - 한도 안내 l10n 키: `quota_limitReachedTitle` ("사용 한도 도달"), `quota_limitReachedMessage` ("이번 달 사용 한도에 도달했어요. 다음 달에 다시 이용할 수 있어요.")
  - 상세: [docs/architecture/quota-system.md](docs/architecture/quota-system.md)
  ```
- [ ] **Step 7: CLAUDE.md Key Dependencies에서 in_app_purchase 제거.**
  old:
  ```markdown
  - **flutter_secure_storage** - Secure JWT token storage
  - **in_app_purchase: ^3.2.0** - App Store / Play Store 결제 (premium subscription)
  - **firebase_core: ^3.12.1** + **firebase_messaging: ^15.2.4** + **firebase_analytics: ^11.4.2** - FCM 푸시 + 분석
  ```
  new:
  ```markdown
  - **flutter_secure_storage** - Secure JWT token storage
  - **firebase_core: ^3.12.1** + **firebase_messaging: ^15.2.4** + **firebase_analytics: ^11.4.2** - FCM 푸시 + 분석
  ```
- [ ] **Step 8: 검증 루프 + 커밋.** Run: `grep -n "premium\|Premium" docs/architecture/quota-system.md` → "프리미엄 tier 제거" 류 갱신 문구만 남고 현행 기능 설명으로서의 premium 분기 서술 0건 확인. `git status --short CLAUDE.md` → 출력 없음(gitignored) 확인. 이상 발견 시 수정 후 재확인, 통과할 때까지 반복. 통과 후 (CLAUDE.md는 git add에 포함하지 않는다):
  ```
  git add docs/architecture/quota-system.md
  git commit -m "|REMOVE| quota-system.md 프리미엄 tier 제거 반영 — 전원 동일 free 한도

  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
  ```

---

**태스크 순서 요약:** 5.1은 전체 계획의 최선행(슬라이스 2·3이 참조할 getter 생성). 5.2/5.3/5.4는 독립 — 언제든 실행 가능. 5.5는 슬라이스 1(premium_screen 삭제) 후. 5.6은 슬라이스 1·2·3(analytics 호출처 제거) 후. 5.7/5.8/5.9는 슬라이스 1~4의 화면 수정·파일 삭제가 모두 끝난 뒤 최후행(5.7 → 5.8 → 5.9 순서 권장). 모든 태스크는 완료 시점에 `flutter analyze` 통과 상태를 유지한다.

---

## 슬라이스 2 — health_check 5화면 프리미엄/SNS 제거

**슬라이스 간 의존성 (판단 결과):**
- `quota_limitReachedTitle` / `quota_limitReachedMessage` 키는 현재 arb 3개 어디에도 없음(grep 확인). Task 2.4가 이 키를 참조하므로 **슬라이스 5의 키 신설 태스크가 선행되어야 하나, 실행 순서 독립성을 위해 Task 2.1을 idempotent 가드(이미 있으면 skip)로 포함**했다. 슬라이스 5 신설 태스크가 먼저 실행됐다면 Task 2.1은 grep 확인 후 no-op으로 통과된다.
- **슬라이스 5의 프리미엄 l10n 키 삭제 태스크(premium_\*, healthCheck_trialExhausted\*, coach_hcTrial\*, visionQuotaBadge\* 등)는 반드시 슬라이스 2 전체 완료 후 실행** — 현재 이 화면들이 해당 키를 라이브 참조 중.
- **슬라이스 1/3의 파일 삭제(premium_provider.dart, premium_service.dart, quota_badge.dart, promo_code_bottom_sheet.dart)도 반드시 슬라이스 2 완료 후 실행** — 참조 제거가 파일 삭제보다 먼저. 이 슬라이스의 모든 태스크는 삭제 예정 파일이 아직 존재하는 상태에서도 각각 컴파일 가능(제거만 하므로).
- 태스크 내부 순서: 2.1 → (2.2, 2.3, 2.5, 2.6 순서 무관) → 2.4는 2.1 이후.

---

### Task 2.1: 중립 l10n 키 보장 (quota_limitReachedTitle/Message) — idempotent
**Files:**
- Modify: `lib/l10n/app_ko.arb` (L913 부근), `lib/l10n/app_en.arb` (L715 부근), `lib/l10n/app_zh.arb` (L882 부근)
- Modify(재생성): `lib/l10n/app_localizations.dart`, `app_localizations_ko.dart`, `app_localizations_en.dart`, `app_localizations_zh.dart` (`flutter gen-l10n`)
- Test: 없음

**Interfaces:** Produces — `AppLocalizations.quota_limitReachedTitle: String`, `AppLocalizations.quota_limitReachedMessage: String` (generated getter). Task 2.4 및 슬라이스 3(ai_encyclopedia 429 처리)이 consume.

- [ ] **Step 1: 키 존재 확인 (idempotent 가드).** Run: `grep -n "quota_limitReachedTitle" lib/l10n/app_ko.arb lib/l10n/app_localizations.dart`. 두 파일 모두에서 발견되면(슬라이스 5 신설 태스크 선행 완료) 이 태스크 전체 skip하고 Task 2.2로 이동. 미발견 시 Step 2 진행.
- [ ] **Step 2: app_ko.arb에 키 추가.** Edit — old:
```json
  "hc_analysisErrorTitle": "분석 중 오류가 발생했습니다",
```
new:
```json
  "hc_analysisErrorTitle": "분석 중 오류가 발생했습니다",
  "quota_limitReachedTitle": "사용 한도 도달",
  "quota_limitReachedMessage": "이번 달 사용 한도에 도달했어요. 다음 달에 다시 이용할 수 있어요.",
```
- [ ] **Step 3: app_en.arb에 키 추가.** Edit — old:
```json
  "hc_analysisErrorTitle": "An error occurred during analysis",
```
new:
```json
  "hc_analysisErrorTitle": "An error occurred during analysis",
  "quota_limitReachedTitle": "Limit Reached",
  "quota_limitReachedMessage": "You've reached this month's usage limit. It resets next month.",
```
- [ ] **Step 4: app_zh.arb에 키 추가.** Edit — old:
```json
  "hc_analysisErrorTitle": "分析过程中出错",
```
new:
```json
  "hc_analysisErrorTitle": "分析过程中出错",
  "quota_limitReachedTitle": "已达使用上限",
  "quota_limitReachedMessage": "本月使用次数已达上限，下月将重置。",
```
- [ ] **Step 5: l10n 재생성.** Run: `flutter gen-l10n` → 기대: exit 0. 이후 `grep -n "quota_limitReachedTitle" lib/l10n/app_localizations.dart` → 기대: getter 선언 1건 이상 출력.
- [ ] **Step 6: 검증 루프.** Run: `flutter analyze` → 기대: `No issues found!`. 실패 시 원인(arb JSON 문법 오류, gen-l10n 미실행 등) 수정 후 재실행, 통과할 때까지 반복. (`Bad state: The analysis server crashed unexpectedly` 크래시 시 재실행 또는 `dart analyze lib`로 대체 — 이 세션 샌드박스에서 크래시 재현됨, 로컬 터미널 실행 권장.) 통과 후 커밋:
```
git add lib/l10n/
git commit -m "|REMOVE| l10n — 쿼터 한도 중립 안내 키 신설 (quota_limitReachedTitle/Message, 프리미엄 제거 선행)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
```

---

### Task 2.2: health_check_main_screen.dart — 잠금/배지/한도 다이얼로그/SNS 문구 제거
**Files:**
- Modify: `lib/src/screens/health_check/health_check_main_screen.dart` (L1-20 imports, L31-101 상태·수명주기, L111-129 coach 스텝, L143-232 paywall·다이얼로그, L280-306 배지 Row, L362-467 모드 카드)
- Test: 없음

**Interfaces:** 없음 (화면 내부 변경만)

- [ ] **Step 1: import 정리.** Edit — old:
```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../models/ai_health_check.dart';
import '../../router/route_names.dart';
import '../../theme/colors.dart';
import '../../services/analytics/analytics_service.dart';
import '../../providers/premium_provider.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/coach_mark_overlay.dart';
import '../../widgets/quota_badge.dart';
import '../../services/premium/premium_service.dart';
import '../../services/coach_mark/coach_mark_service.dart';
import '../../theme/durations.dart';
import '../premium/promo_code_bottom_sheet.dart';
```
new:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../models/ai_health_check.dart';
import '../../router/route_names.dart';
import '../../theme/colors.dart';
import '../../widgets/coach_mark_overlay.dart';
import '../../services/coach_mark/coach_mark_service.dart';
import '../../theme/durations.dart';
```
(`dart:async`·`dart:io`는 `_loadPremiumStatus`의 SocketException/TimeoutException 처리 전용이었으므로 함께 제거. `app_snack_bar.dart`도 동일.)
- [ ] **Step 2: 상태 필드·옵저버·_loadPremiumStatus 제거.** Edit — old:
```dart
class _HealthCheckMainScreenState extends ConsumerState<HealthCheckMainScreen>
    with WidgetsBindingObserver {
  bool _isLocked = true; // 기본값: 잠금 (로딩 중 오탭 방지)
  bool _hasVisionTrial = false; // Phase 2: 무료 체험 가능 여부
  int _visionRemaining = 0; // 남은 비전 체험 횟수
  bool _isLoading = true;

  // Coach mark target keys
  final _historyButtonKey = GlobalKey();
  final _modeCardsKey = GlobalKey();
  final _trialBadgeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPremiumStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPremiumStatus(forceRefresh: true);
    }
  }

  Future<void> _loadPremiumStatus({bool forceRefresh = false}) async {
    try {
      if (forceRefresh) {
        await ref.read(premiumStatusProvider.notifier).refresh();
      }
      final status = await ref.read(premiumStatusProvider.future);
      if (mounted) {
        setState(() {
          if (status.isPremium) {
            // 프리미엄: 무제한 사용
            _isLocked = false;
            _hasVisionTrial = false;
            _visionRemaining = -1;
          } else {
            // Phase 2: Free 사용자 3단 상태
            final remaining = status.quota?.vision.remaining ?? 0;
            _visionRemaining = remaining;
            _isLocked = remaining <= 0; // 체험 소진 → 잠금
            _hasVisionTrial = remaining > 0; // 체험 가능 → 열림 + 배지
          }
          _isLoading = false;
        });
        _maybeShowCoachMarks();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLocked = true;
          _hasVisionTrial = false;
          _isLoading = false;
        });
        // 네트워크 에러 시 사용자에게 안내 (프리미엄 상태 확인 불가)
        if (e is SocketException || e is TimeoutException) {
          final l10n = AppLocalizations.of(context);
          AppSnackBar.error(context, message: l10n.error_network);
        }
      }
    }
  }
```
new:
```dart
class _HealthCheckMainScreenState extends ConsumerState<HealthCheckMainScreen> {
  // Coach mark target keys
  final _historyButtonKey = GlobalKey();
  final _modeCardsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _maybeShowCoachMarks();
  }
```
- [ ] **Step 3: coach_hcTrial 스텝 제거.** Edit — old:
```dart
    final steps = [
      CoachMarkStep(
        targetKey: _historyButtonKey,
        title: l10n.coach_hcHistory_title,
        body: l10n.coach_hcHistory_body,
        isScrollable: false,
      ),
      CoachMarkStep(
        targetKey: _modeCardsKey,
        title: l10n.coach_hcModes_title,
        body: l10n.coach_hcModes_body,
      ),
      if (!_isLocked && _hasVisionTrial)
        CoachMarkStep(
          targetKey: _trialBadgeKey,
          title: l10n.coach_hcTrial_title,
          body: l10n.coach_hcTrial_body,
        ),
    ];
```
new:
```dart
    final steps = [
      CoachMarkStep(
        targetKey: _historyButtonKey,
        title: l10n.coach_hcHistory_title,
        body: l10n.coach_hcHistory_body,
        isScrollable: false,
      ),
      CoachMarkStep(
        targetKey: _modeCardsKey,
        title: l10n.coach_hcModes_title,
        body: l10n.coach_hcModes_body,
      ),
    ];
```
- [ ] **Step 4: `_openPremiumPaywall` + `_showPremiumDialog`(한도 다이얼로그·PromoCodeBottomSheet·SNS 문구) 통째 삭제.** Edit — old (L143-232, 뒤따르는 빈 줄 1개 포함 삭제):
```dart
  // ignore: unused_element — App Store 3.1.1 대응으로 호출부 제거됨, IAP 복원 시 재사용
  Future<void> _openPremiumPaywall({
    required String source,
    required String feature,
  }) async {
    await context.push('/home/premium?source=$source&feature=$feature');
    if (!mounted) return;
    await _loadPremiumStatus(forceRefresh: true);
  }

  void _showPremiumDialog({bool isTrialExhausted = false}) {
    final l10n = AppLocalizations.of(context);
    final title = isTrialExhausted
        ? l10n.healthCheck_trialExhaustedTitle
        : l10n.premium_featureLockedTitle;
    // 사전 사업자등록: 프로모션 코드/SNS 안내 메시지 사용
    final message = isTrialExhausted
        ? l10n.healthCheck_trialExhaustedMessage_v2
        : l10n.healthCheck_trialExhaustedMessage_v2;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.card_giftcard,
              color: AppColors.brandPrimary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.nearBlack,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.mediumGray,
            height: 1.5,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              l10n.premium_maybeLater,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.mediumGray,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              AnalyticsService.instance.logPremiumFeatureBlocked(
                feature: 'vision',
                sourceScreen: 'health_check_main',
              );
              final activated = await PromoCodeBottomSheet.show(context);
              if (activated == true && mounted) {
                await _loadPremiumStatus(forceRefresh: true);
              }
            },
            child: Text(
              l10n.healthCheck_trialExhaustedAction_promo,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.brandPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
```
new: (빈 문자열 — 전체 삭제)
- [ ] **Step 5: VisionQuotaBadge Row 제거.** Edit — old:
```dart
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.hc_selectTarget,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mediumGray,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  // 비전 쿼터 배지 — 카드 목록 상단에 한 번만 표시
                  if (_hasVisionTrial)
                    VisionQuotaBadge(
                      key: _trialBadgeKey,
                      quota: VisionQuota(
                        monthlyLimit: 30,
                        monthlyUsed: 30 - _visionRemaining,
                        remaining: _visionRemaining,
                      ),
                      normalText: l10n.visionQuotaBadge_normal(_visionRemaining),
                      exhaustedText: l10n.visionQuotaBadge_exhausted,
                    ),
                ],
              ),
```
new:
```dart
              Text(
                l10n.hc_selectTarget,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mediumGray,
                  letterSpacing: -0.4,
                ),
              ),
```
- [ ] **Step 6: `_buildModeCard` 잠금 로직 제거.** Edit — old:
```dart
  Widget _buildModeCard(
    BuildContext context, {
    required AppLocalizations l10n,
    required VisionMode mode,
    required IconData icon,
    required String description,
  }) {
    final locked = _isLocked && !_isLoading;

    return Semantics(
      button: true,
      label: _getModeLabel(l10n, mode),
      child: GestureDetector(
      onTap: () {
        if (locked) {
          _showPremiumDialog(isTrialExhausted: true);
        } else if (!_isLoading) {
          context.pushNamed(
            RouteNames.healthCheckCapture,
            extra: {'mode': mode},
          );
        }
      },
      child: Opacity(
        opacity: locked ? 0.45 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: locked
                      ? AppColors.gray250
                      : AppColors.brandLight,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: mode == VisionMode.fullBody
                    ? SvgPicture.asset(
                        'assets/images/brand.svg',
                        width: 24,
                        height: 24,
                        colorFilter: ColorFilter.mode(
                          locked
                              ? AppColors.gray500
                              : AppColors.brandPrimary,
                          BlendMode.srcIn,
                        ),
                      )
                    : Icon(
                        icon,
                        color: locked
                            ? AppColors.gray500
                            : AppColors.brandPrimary,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _getModeLabel(l10n, mode),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.nearBlack,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.mediumGray,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                locked ? Icons.lock_outline : Icons.chevron_right,
                color: AppColors.warmGray,
                size: 24,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
```
new:
```dart
  Widget _buildModeCard(
    BuildContext context, {
    required AppLocalizations l10n,
    required VisionMode mode,
    required IconData icon,
    required String description,
  }) {
    return Semantics(
      button: true,
      label: _getModeLabel(l10n, mode),
      child: GestureDetector(
        onTap: () {
          context.pushNamed(
            RouteNames.healthCheckCapture,
            extra: {'mode': mode},
          );
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.brandLight,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: mode == VisionMode.fullBody
                    ? SvgPicture.asset(
                        'assets/images/brand.svg',
                        width: 24,
                        height: 24,
                        colorFilter: const ColorFilter.mode(
                          AppColors.brandPrimary,
                          BlendMode.srcIn,
                        ),
                      )
                    : Icon(
                        icon,
                        color: AppColors.brandPrimary,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getModeLabel(l10n, mode),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.nearBlack,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.mediumGray,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: AppColors.warmGray,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
```
- [ ] **Step 7: 잔존 심볼 grep 확인.** Run: `grep -n "premiumStatusProvider\|VisionQuotaBadge\|PromoCodeBottomSheet\|_isLocked\|_hasVisionTrial\|_visionRemaining\|_loadPremiumStatus\|_showPremiumDialog\|_openPremiumPaywall\|_trialBadgeKey\|_isLoading\|coach_hcTrial\|healthCheck_trialExhausted\|premium_" lib/src/screens/health_check/health_check_main_screen.dart` → 기대: 출력 없음(exit 1). 출력이 있으면 해당 잔존 참조를 제거하고 재확인.
- [ ] **Step 8: 검증 루프.** Run: `flutter analyze` → 기대: `No issues found!` (unused import/unused element 경고 포함 0). 실패 시 원인 수정 후 재실행, 통과할 때까지 반복 (analysis server 크래시 시 재시도/`dart analyze lib`). 통과 후 커밋:
```
git add lib/src/screens/health_check/health_check_main_screen.dart
git commit -m "|REMOVE| 건강체크 메인 — 비전 잠금 UI·쿼터 배지·프로모/SNS 한도 다이얼로그 제거

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
```

---

### Task 2.3: health_check_capture_screen.dart — `_checkPremium()` 리다이렉트 제거
**Files:**
- Modify: `lib/src/screens/health_check/health_check_capture_screen.dart` (L9 import, L35-57)
- Test: 없음

**Interfaces:** 없음

- [ ] **Step 1: premium_provider import 제거.** Edit — old:
```dart
import '../../models/ai_health_check.dart';
import '../../router/route_names.dart';
import '../../providers/premium_provider.dart';
import '../../theme/colors.dart';
```
new:
```dart
import '../../models/ai_health_check.dart';
import '../../router/route_names.dart';
import '../../theme/colors.dart';
```
- [ ] **Step 2: initState + `_checkPremium` 삭제.** (initState는 `_checkPremium()` 호출 외 내용이 없으므로 override 자체를 삭제. `kDebugMode`/`debugPrint`는 이 메서드 전용이었지만 `flutter/foundation.dart` import는 `Uint8List` 때문에 유지.) Edit — old:
```dart
  @override
  void initState() {
    super.initState();
    _checkPremium();
  }

  Future<void> _checkPremium() async {
    try {
      final status = await ref.read(premiumStatusProvider.future);
      // Phase 2: quota 기반 접근 체크 (trial remaining > 0이면 허용)
      final hasAccess = status.isPremium ||
          (status.quota?.vision.remaining ?? 0) > 0;
      if (mounted && !hasAccess) {
        context.goNamed(RouteNames.healthCheck);
      }
    } catch (e) {
      // 쿼터 조회 실패 시 화면을 유지하고 서버 API의 403 응답에 위임
      // (네트워크 오류 등 일시적 장애로 유저를 차단하지 않기 위함)
      if (kDebugMode) {
        debugPrint('[HealthCheckCapture] premium check failed: $e');
      }
    }
  }

  @override
  void dispose() {
```
new:
```dart
  @override
  void dispose() {
```
- [ ] **Step 3: 잔존 심볼 grep 확인.** Run: `grep -n "premiumStatusProvider\|_checkPremium\|premium" lib/src/screens/health_check/health_check_capture_screen.dart` → 기대: 출력 없음(exit 1).
- [ ] **Step 4: 검증 루프.** Run: `flutter analyze` → 기대: `No issues found!`. 실패 시 원인 수정 후 재실행, 통과할 때까지 반복. 통과 후 커밋:
```
git add lib/src/screens/health_check/health_check_capture_screen.dart
git commit -m "|REMOVE| 건강체크 캡처 — 진입 시 프리미엄 사전 체크 리다이렉트 제거

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
```

---

### Task 2.4: health_check_analyzing_screen.dart — 사전 체크·체험 analytics 제거, 403은 중립 키로 유지
**선행 조건: Task 2.1 완료** (`l10n.quota_limitReachedTitle/Message` getter 필요 — 미완료 상태로 진행하면 analyze 실패)

**Files:**
- Modify: `lib/src/screens/health_check/health_check_analyzing_screen.dart` (L12-13 imports, L61-81, L133-146, L177-184, L330-333)
- Test: 없음

**Interfaces:** Consumes — `AppLocalizations.quota_limitReachedTitle`, `AppLocalizations.quota_limitReachedMessage` (Task 2.1 산출)

- [ ] **Step 1: 선행 조건 확인.** Run: `grep -n "quota_limitReachedMessage" lib/l10n/app_localizations.dart` → 기대: getter 1건 이상. 없으면 Task 2.1을 먼저 완료.
- [ ] **Step 2: analytics/premium import 제거.** Edit — old:
```dart
import '../../services/health_check/health_check_service.dart';
import '../../providers/pet_providers.dart';
import '../../services/analytics/analytics_service.dart';
import '../../providers/premium_provider.dart';
import '../../services/api/api_client.dart';
```
new:
```dart
import '../../services/health_check/health_check_service.dart';
import '../../providers/pet_providers.dart';
import '../../services/api/api_client.dart';
```
- [ ] **Step 3: `_checkPremiumThenAnalyze` 제거 — initState가 바로 `_startAnalysis()` 호출.** Edit — old:
```dart
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPremiumThenAnalyze();
    });
  }

  Future<void> _checkPremiumThenAnalyze() async {
    try {
      final status = await ref.read(premiumStatusProvider.future);
      // Phase 2: quota 기반 접근 체크 (trial remaining > 0이면 허용)
      final hasAccess = status.isPremium ||
          (status.quota?.vision.remaining ?? 0) > 0;
      if (mounted && !hasAccess) {
        context.goNamed(RouteNames.healthCheck);
        return;
      }
    } catch (_) {
      // 프리미엄 확인 실패 시에도 분석 진행 (서버 API에서 403으로 재차단)
    }
    if (!mounted) return;
    _startAnalysis();
  }
```
new:
```dart
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAnalysis();
    });
  }
```
- [ ] **Step 4: 분석 후 refreshAndGet + logVisionTrialUsed 블록 제거.** Edit — old:
```dart
      if (!mounted || _cancelled) return;
      debugPrint('[HealthCheck] Analysis response received');

      // Phase 2: Vision 체험 사용 analytics (Free 사용자만)
      try {
        final postStatus = await ref.read(premiumStatusProvider.notifier).refreshAndGet();
        if (!postStatus.isPremium) {
          AnalyticsService.instance.logVisionTrialUsed(
            remainingAfter: postStatus.quota?.vision.remaining ?? 0,
          );
        }
      } catch (_) {}

      // 백엔드 응답: { id, pet_id, check_type, result: { findings, ... }, ... }
```
new:
```dart
      if (!mounted || _cancelled) return;
      debugPrint('[HealthCheck] Analysis response received');

      // 백엔드 응답: { id, pet_id, check_type, result: { findings, ... }, ... }
```
- [ ] **Step 5: 403 에러 메시지를 중립 키로 교체 (처리 자체는 유지 — 서버 쿼터 응답 안내).** Edit — old:
```dart
        _errorMessage = e.statusCode == 403
            ? l10n.premium_healthCheckBlocked
            : (e.statusCode >= 500 ? l10n.error_server : l10n.hc_analysisError);
```
new:
```dart
        _errorMessage = e.statusCode == 403
            ? l10n.quota_limitReachedMessage
            : (e.statusCode >= 500 ? l10n.error_server : l10n.hc_analysisError);
```
- [ ] **Step 6: 403 에러 타이틀을 중립 키로 교체.** Edit — old:
```dart
              _isQuotaExhausted
                  ? l10n.premium_healthCheckBlockedTitle
                  : l10n.hc_analysisErrorTitle,
```
new:
```dart
              _isQuotaExhausted
                  ? l10n.quota_limitReachedTitle
                  : l10n.hc_analysisErrorTitle,
```
- [ ] **Step 7: 잔존 심볼 grep 확인.** Run: `grep -n "premiumStatusProvider\|_checkPremiumThenAnalyze\|logVisionTrialUsed\|AnalyticsService\|premium_healthCheckBlocked" lib/src/screens/health_check/health_check_analyzing_screen.dart` → 기대: 출력 없음(exit 1). (`_isQuotaExhausted`는 403 안내 UI용으로 잔존이 정상.)
- [ ] **Step 8: 검증 루프.** Run: `flutter analyze` → 기대: `No issues found!`. 실패 시 원인 수정 후 재실행, 통과할 때까지 반복. 통과 후 커밋:
```
git add lib/src/screens/health_check/health_check_analyzing_screen.dart
git commit -m "|REMOVE| 건강체크 분석 — 프리미엄 사전 체크·체험 analytics 제거, 403은 중립 한도 안내로 유지

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
```

---

### Task 2.5: vet_summary_screen.dart — isFree 공유 게이트 제거
**Files:**
- Modify: `lib/src/screens/health_check/vet_summary_screen.dart` (L8 import, L35-46)
- Test: 없음

**Interfaces:** 없음

- [ ] **Step 1: premium_provider import 제거.** Edit — old:
```dart
import '../../services/api/api_client.dart';
import '../../providers/premium_provider.dart';
import '../../providers/pet_providers.dart';
```
new:
```dart
import '../../services/api/api_client.dart';
import '../../providers/pet_providers.dart';
```
- [ ] **Step 2: isFree 게이트 제거 — 서버 응답(ApiException catch → `report_shareFailed`)에 위임.** Edit — old:
```dart
    try {
      final status = await ref.read(premiumStatusProvider.future);
      if (status.isFree) {
        // App Store 3.1.1 대응: 업그레이드 CTA 제거 — 중립 실패 메시지만 표시
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.report_shareFailed)),
          );
        }
        return;
      }

      final result = await ApiClient.instance.post(
```
new:
```dart
    try {
      final result = await ApiClient.instance.post(
```
- [ ] **Step 3: 잔존 심볼 grep 확인.** Run: `grep -n "premiumStatusProvider\|isFree\|premium" lib/src/screens/health_check/vet_summary_screen.dart` → 기대: 출력 없음(exit 1).
- [ ] **Step 4: 검증 루프.** Run: `flutter analyze` → 기대: `No issues found!`. 실패 시 원인 수정 후 재실행, 통과할 때까지 반복. 통과 후 커밋:
```
git add lib/src/screens/health_check/vet_summary_screen.dart
git commit -m "|REMOVE| 병원 요약 공유 — 프리미엄 isFree 게이트 제거 (서버 응답 처리로 일원화)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
```

---

### Task 2.6: health_check_history_screen.dart — 공유 isFree 게이트 제거
**Files:**
- Modify: `lib/src/screens/health_check/health_check_history_screen.dart` (L12 import, L195-207)
- Test: 없음

**Interfaces:** 없음

- [ ] **Step 1: premium_provider import 제거.** Edit — old:
```dart
import '../../services/api/api_client.dart';
import '../../providers/premium_provider.dart';
import '../../services/storage/health_check_storage_service.dart';
```
new:
```dart
import '../../services/api/api_client.dart';
import '../../services/storage/health_check_storage_service.dart';
```
- [ ] **Step 2: `_shareHealthReport`의 isFree 게이트 제거.** Edit — old:
```dart
    try {
      final status = await ref.read(premiumStatusProvider.future);
      if (status.isFree) {
        // App Store 3.1.1 대응: 업그레이드 CTA 제거 — 중립 실패 메시지만 표시
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.report_shareFailed)),
          );
        }
        return;
      }

      final now = DateTime.now();
```
new:
```dart
    try {
      final now = DateTime.now();
```
- [ ] **Step 3: 잔존 심볼 grep 확인 (슬라이스 완료 게이트 겸용 — 디렉토리 전체).** Run: `grep -rn "premiumStatusProvider\|premium_provider\|VisionQuotaBadge\|PromoCodeBottomSheet\|isFree\|healthCheck_trialExhausted\|coach_hcTrial\|premium_healthCheckBlocked" lib/src/screens/health_check/` → 기대: 출력 없음(exit 1). 출력이 있으면 해당 파일의 태스크로 돌아가 잔존 참조 제거.
- [ ] **Step 4: 검증 루프.** Run: `flutter analyze` → 기대: `No issues found!`. 실패 시 원인 수정 후 재실행, 통과할 때까지 반복. 통과 후 커밋:
```
git add lib/src/screens/health_check/health_check_history_screen.dart
git commit -m "|REMOVE| 건강체크 히스토리 — 리포트 공유 프리미엄 isFree 게이트 제거

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
```

---

**참고 (검증 환경):** 이 세션 샌드박스에서 `flutter analyze`/`dart analyze`가 `Bad state: The analysis server crashed unexpectedly`로 크래시함을 확인 — 실행 시 동일 크래시가 나면 재실행하거나 샌드박스 밖(로컬 터미널/`dangerouslyDisableSandbox`)에서 실행할 것. 크래시는 코드 이슈가 아니므로 검증 실패로 간주하지 않는다.

---

## Slice 3: ai_encyclopedia_screen.dart 프리미엄/쿼터 UI 제거

> **선행 조건**: 없음 (Task 3.1이 중립 l10n 키를 idempotent하게 생성). 다른 슬라이스가 먼저 `quota_limitReached*` 키를 추가했다면 Task 3.1의 Step 2~4는 자동 skip된다.
> **주의**: 이 슬라이스는 `aiEncyclopedia_quotaExhausted`/`quotaBadge_*`/`chatbot_premiumBanner`/`chatbot_premiumUpgrade` 키의 **코드 참조를 제거**한다 (키 자체 삭제는 l10n 슬라이스 담당 — 참조 제거가 키 삭제보다 반드시 먼저).

### Task 3.1: 중립 한도 안내 l10n 키 신설 (ko/en/zh) + gen-l10n

**Files:**
- Modify: `/Users/imdonghyeon/perch_care/lib/l10n/app_ko.arb` (파일 끝, `common_defaultPetName` 직후)
- Modify: `/Users/imdonghyeon/perch_care/lib/l10n/app_en.arb` (파일 끝)
- Modify: `/Users/imdonghyeon/perch_care/lib/l10n/app_zh.arb` (파일 끝)
- Regenerate: `/Users/imdonghyeon/perch_care/lib/l10n/app_localizations*.dart` (flutter gen-l10n)

**Interfaces:**
- Consumes: 없음
- Produces: `AppLocalizations.quota_limitReachedTitle` (String getter), `AppLocalizations.quota_limitReachedMessage` (String getter) — Task 3.2 및 타 슬라이스(health_check/vision 등)가 소비

- [ ] **Step 1: 분석 베이스라인 기록.** Run: `cd /Users/imdonghyeon/perch_care && flutter analyze`. 현재 이슈 개수/목록을 기록한다 (기대: `No issues found!`. 기존 이슈가 있다면 목록을 남기고, 이후 태스크에서는 "새 이슈 0건"을 통과 기준으로 삼는다).

- [ ] **Step 2: 키 존재 여부 확인 (idempotency 가드).** Run: `grep -c "quota_limitReachedMessage" /Users/imdonghyeon/perch_care/lib/l10n/app_ko.arb`. 결과가 `1` 이상이면 다른 슬라이스가 이미 추가한 것 — Step 3~5를 건너뛰고 Step 6으로 간다. `0`이면 계속.

- [ ] **Step 3: app_ko.arb에 키 추가.** Edit `/Users/imdonghyeon/perch_care/lib/l10n/app_ko.arb`:

old:
```json
  "hc_analysisTimeout": "분석 시간이 너무 오래 걸려요. 네트워크를 확인하고 다시 시도해주세요.",

  "common_defaultPetName": "사랑이"
}
```
new:
```json
  "hc_analysisTimeout": "분석 시간이 너무 오래 걸려요. 네트워크를 확인하고 다시 시도해주세요.",

  "common_defaultPetName": "사랑이",

  "quota_limitReachedTitle": "사용 한도 도달",
  "quota_limitReachedMessage": "이번 달 사용 한도에 도달했어요. 다음 달에 다시 이용할 수 있어요."
}
```

- [ ] **Step 4: app_en.arb에 키 추가.** Edit `/Users/imdonghyeon/perch_care/lib/l10n/app_en.arb`:

old:
```json
  "hc_analysisTimeout": "The analysis is taking too long. Please check your connection and try again.",

  "common_defaultPetName": "Buddy"
}
```
new:
```json
  "hc_analysisTimeout": "The analysis is taking too long. Please check your connection and try again.",

  "common_defaultPetName": "Buddy",

  "quota_limitReachedTitle": "Limit Reached",
  "quota_limitReachedMessage": "You've reached this month's usage limit. It resets next month."
}
```

- [ ] **Step 5: app_zh.arb에 키 추가.** Edit `/Users/imdonghyeon/perch_care/lib/l10n/app_zh.arb`:

old:
```json
  "hc_analysisTimeout": "分析耗时过长。请检查网络后重试。",

  "common_defaultPetName": "宝贝"
}
```
new:
```json
  "hc_analysisTimeout": "分析耗时过长。请检查网络后重试。",

  "common_defaultPetName": "宝贝",

  "quota_limitReachedTitle": "已达使用上限",
  "quota_limitReachedMessage": "本月使用次数已达上限，下月将重置。"
}
```

- [ ] **Step 6: l10n 재생성.** Run: `cd /Users/imdonghyeon/perch_care && flutter gen-l10n`. 기대: 에러 없이 종료. 확인: `grep -n "quota_limitReachedMessage" /Users/imdonghyeon/perch_care/lib/l10n/app_localizations.dart` → getter 선언이 출력되어야 함.

- [ ] **Step 7: 검증 루프.** Run: `cd /Users/imdonghyeon/perch_care && flutter analyze` → 기대: `No issues found!` (또는 Step 1 베이스라인 대비 새 이슈 0건). 실패 시 원인(arb 문법 오류, 키 중복 등) 수정 후 재실행, 통과할 때까지 반복 → 통과 후 커밋:
```bash
cd /Users/imdonghyeon/perch_care && git add lib/l10n/ && git commit -m "|REMOVE| 중립 한도 안내 l10n 키 신설 (quota_limitReachedTitle/Message ko·en·zh)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
```
(Step 2에서 skip했고 gen-l10n 결과 diff도 없다면 커밋 없이 태스크 종료.)

---

### Task 3.2: AI백과 쿼터 상태·배지·사전 차단 UI 제거 + 429 중립 메시지 교체

**Files:**
- Modify: `/Users/imdonghyeon/perch_care/lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart` (L17·29·32, L69-71, L112-146, L244-251, L320-337, L373-381, L516-531, L712-727, L1209-1218 — 원본 기준)

**Interfaces:**
- Consumes: `AppLocalizations.quota_limitReachedMessage` (Task 3.1 산출물)
- Produces: 없음 (이 태스크 이후 이 파일에서 `PremiumStatus`·`QuotaBadge`·`premiumStatusProvider.notifier` 참조 소멸 — 단 배너의 `premiumStatusProvider` 참조는 Task 3.3까지 잔존)

- [ ] **Step 1: `_handleSend`의 쿼터 소진 사전 차단 블록 제거.** Edit (사전 차단 UI 전면 제거 — 서버 429가 유일한 게이트):

old:
```dart
    // Phase 2: 쿼터 소진 시 전송 차단
    if (_isQuotaExhausted) {
      AppSnackBar.error(
        context,
        message: AppLocalizations.of(context).aiEncyclopedia_quotaExhausted,
      );
      return;
    }

    AnalyticsService.instance.logAiChatSent();
```
new:
```dart
    AnalyticsService.instance.logAiChatSent();
```

- [ ] **Step 2: SSE 경로 429 처리를 중립 키로 교체.** Edit (쿼터 새로고침·`logQuotaReached` 제거 — `_premiumStatus` 의존 소멸, 429 안내 자체는 유지):

old:
```dart
      // Phase 2: 429 quota exceeded → quota 새로고침 + 에러 표시
      if (e is ApiException && e.statusCode == 429) {
        debugPrint('[AIEncyclopedia] Quota exceeded (429)');
        AnalyticsService.instance.logQuotaReached(
          feature: 'ai_encyclopedia',
          usedCount: _premiumStatus?.quota?.aiEncyclopedia.monthlyUsed ?? 0,
        );
        _loadQuota();
        setState(() {
          _updateAssistantMessage(
            text: AppLocalizations.of(context).aiEncyclopedia_quotaExhausted,
            timestamp: DateTime.now(),
          );
          _isSending = false;
        });
        _assistantPlaceholderIndex = null;
        return;
      }
```
new:
```dart
      // 서버 쿼터 초과(429) → 중립 한도 안내 메시지 표시
      if (e is ApiException && e.statusCode == 429) {
        debugPrint('[AIEncyclopedia] Quota exceeded (429)');
        setState(() {
          _updateAssistantMessage(
            text: AppLocalizations.of(context).quota_limitReachedMessage,
            timestamp: DateTime.now(),
          );
          _isSending = false;
        });
        _assistantPlaceholderIndex = null;
        return;
      }
```

- [ ] **Step 3: fallback 경로 429 처리를 중립 키로 교체.** Edit:

old:
```dart
      // Phase 2: 429 quota exceeded → quota 새로고침 + 에러 표시
      if (e is ApiException && e.statusCode == 429) {
        debugPrint('[AIEncyclopedia] Fallback quota exceeded (429)');
        AnalyticsService.instance.logQuotaReached(
          feature: 'ai_encyclopedia',
          usedCount: _premiumStatus?.quota?.aiEncyclopedia.monthlyUsed ?? 0,
        );
        _loadQuota();
        setState(() {
          _updateAssistantMessage(
            text: l10nErr.aiEncyclopedia_quotaExhausted,
            timestamp: DateTime.now(),
          );
        });
        return;
      }
```
new:
```dart
      // 서버 쿼터 초과(429) → 중립 한도 안내 메시지 표시
      if (e is ApiException && e.statusCode == 429) {
        debugPrint('[AIEncyclopedia] Fallback quota exceeded (429)');
        setState(() {
          _updateAssistantMessage(
            text: l10nErr.quota_limitReachedMessage,
            timestamp: DateTime.now(),
          );
        });
        return;
      }
```

- [ ] **Step 4: `_finishStreaming`의 quota 갱신 호출 제거.** Edit:

old:
```dart
      _saveAssistantMessageToServer(); // placeholder 인덱스 초기화 전에 호출
      _scrollToBottom();
      _loadQuota(); // Phase 2: 전송 완료 후 quota 배지 갱신
    }
```
new:
```dart
      _saveAssistantMessageToServer(); // placeholder 인덱스 초기화 전에 호출
      _scrollToBottom();
    }
```

- [ ] **Step 5: `_initializeChat`의 `_loadQuota` 호출 제거.** Edit:

old:
```dart
    _maybeShowCoachMarks();
    _loadPremiumBannerState();
    _loadQuota(logView: true);
  }
```
new:
```dart
    _maybeShowCoachMarks();
    _loadPremiumBannerState();
  }
```

- [ ] **Step 6: `_loadQuota` 메서드 전체 제거.** Edit (마지막 호출자가 Step 2~5에서 이미 제거됨):

old:
```dart
  /// Phase 2: 쿼터 정보 로드 (forceRefresh로 최신 데이터 조회)
  /// [logView] true일 때만 ai_quota_viewed analytics 이벤트를 발화 (화면 진입 시만).
  Future<void> _loadQuota({bool logView = false}) async {
    try {
      final status =
          await ref.read(premiumStatusProvider.notifier).refreshAndGet();
      if (mounted) {
        setState(() {
          _premiumStatus = status;
          _isQuotaExhausted =
              status.quota?.aiEncyclopedia.isExhausted ?? false;
        });
        // 쿼터 조회 analytics (화면 진입 시에만)
        if (logView) {
          final quota = status.quota;
          if (quota != null && !quota.aiEncyclopedia.isUnlimited) {
            AnalyticsService.instance.logQuotaViewed(
              remaining: quota.aiEncyclopedia.remaining,
              tier: status.tier,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[AIEncyclopedia] Failed to load quota: $e');
    }
  }

  String get _bannerDismissKey {
```
new:
```dart
  String get _bannerDismissKey {
```

- [ ] **Step 7: appBar 하단 QuotaBadge 제거.** Edit (build 메서드의 `bottom:` 인자 전체 삭제):

old:
```dart
        bottom: _premiumStatus?.quota != null &&
                !_premiumStatus!.quota!.aiEncyclopedia.isUnlimited
            ? PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: QuotaBadge(
                    quota: _premiumStatus!.quota!.aiEncyclopedia,
                    normalText: l10n.quotaBadge_normal(
                      _premiumStatus!.quota!.aiEncyclopedia.remaining,
                    ),
                    exhaustedText: l10n.quotaBadge_exhausted,
                  ),
                ),
              )
            : null,
      ),
```
new:
```dart
      ),
```

- [ ] **Step 8: 입력창의 쿼터 소진 비활성화/힌트 분기 제거.** Edit (`_buildInputArea` 내):

old:
```dart
              child: TextField(
                controller: _inputController,
                enabled: !_isQuotaExhausted,
                onTapOutside: (event) => FocusScope.of(context).unfocus(),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: _isQuotaExhausted
                      ? l10n.aiEncyclopedia_quotaExhaustedHint
                      : l10n.chatbot_inputHint,
                ),
```
new:
```dart
              child: TextField(
                controller: _inputController,
                onTapOutside: (event) => FocusScope.of(context).unfocus(),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: l10n.chatbot_inputHint,
                ),
```

- [ ] **Step 9: 상태 필드 `_premiumStatus`·`_isQuotaExhausted` 제거.** Edit (모든 읽기/쓰기 참조가 Step 1~8에서 제거되었으므로 이제 안전 — `_showPremiumBanner`는 Task 3.3까지 유지):

old:
```dart
  bool _isSending = false;
  bool _isTyping = false;
  bool _isLoadingMessages = true;
  bool _showPremiumBanner = false;
  PremiumStatus? _premiumStatus;
  bool _isQuotaExhausted = false;
```
new:
```dart
  bool _isSending = false;
  bool _isTyping = false;
  bool _isLoadingMessages = true;
  bool _showPremiumBanner = false;
```

- [ ] **Step 10: 불필요해진 import 2건 제거.** Edit (`QuotaBadge`는 Step 7에서, `PremiumStatus` 타입은 Step 9에서 마지막 사용 소멸. `premium_provider.dart` import는 배너 코드가 아직 쓰므로 유지):

old:
```dart
import '../../widgets/local_image_avatar.dart';
import '../../widgets/quota_badge.dart';
```
new:
```dart
import '../../widgets/local_image_avatar.dart';
```

old:
```dart
import '../../theme/durations.dart';
import '../../services/premium/premium_service.dart';
import '../../providers/premium_provider.dart';
```
new:
```dart
import '../../theme/durations.dart';
import '../../providers/premium_provider.dart';
```

- [ ] **Step 11: 잔존 참조 확인.** Run: `grep -n "_premiumStatus\|_isQuotaExhausted\|_loadQuota\|QuotaBadge\|quotaBadge_\|aiEncyclopedia_quotaExhausted\|logQuotaViewed\|logQuotaReached\|premium_service" /Users/imdonghyeon/perch_care/lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart` → 기대: 출력 0줄. 출력이 있으면 해당 라인을 위 스텝들의 패턴대로 제거 후 재확인.

- [ ] **Step 12: 검증 루프.** Run: `cd /Users/imdonghyeon/perch_care && flutter analyze` → 기대: `No issues found!` (또는 Task 3.1 베이스라인 대비 새 이슈 0건. 특히 unused_field/unused_import가 새로 나오면 안 됨). 실패 시 원인 수정 후 재실행, 통과할 때까지 반복 → 통과 후 커밋:
```bash
cd /Users/imdonghyeon/perch_care && git add lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart && git commit -m "|REMOVE| AI백과 쿼터 배지·사전 차단 UI 제거, 429는 중립 한도 안내로 교체

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
```

---

### Task 3.3: AI백과 dead 프리미엄 배너 및 잔여 프리미엄 참조 제거

**Files:**
- Modify: `/Users/imdonghyeon/perch_care/lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart` (원본 기준 L11·33·35·37, L69, L116, L148-180, L741, L1096-1186 — Task 3.2 이후 라인은 위로 시프트됨, old 코드블록 텍스트로 매칭)

**Interfaces:**
- Consumes: 없음
- Produces: 없음 (이 태스크 완료 후 이 파일의 `chatbot_premiumBanner`·`chatbot_premiumUpgrade`·`premiumStatusProvider`·`/home/premium` 참조 전부 소멸 — l10n 슬라이스의 키 삭제 및 premium 화면/프로바이더 삭제 슬라이스의 선행 조건 충족)

- [ ] **Step 1: `_initializeChat`의 배너 로드 호출 제거.** Edit:

old:
```dart
  Future<void> _initializeChat() async {
    await _loadActivePet();
    await _loadMessages();
    _maybeShowCoachMarks();
    _loadPremiumBannerState();
  }
```
new:
```dart
  Future<void> _initializeChat() async {
    await _loadActivePet();
    await _loadMessages();
    _maybeShowCoachMarks();
  }
```

- [ ] **Step 2: build 메서드의 배너 조건부 렌더 제거.** Edit:

old:
```dart
            if (!_hasUserMessages && !_isLoadingMessages)
              _buildSuggestionChips(),
            if (_showPremiumBanner) _buildPremiumBanner(),
            _buildInputArea(),
```
new:
```dart
            if (!_hasUserMessages && !_isLoadingMessages)
              _buildSuggestionChips(),
            _buildInputArea(),
```

- [ ] **Step 3: 배너 상태 메서드 3종(`_bannerDismissKey`·`_loadPremiumBannerState`·`_dismissPremiumBanner`) 제거.** Edit:

old:
```dart
  String get _bannerDismissKey {
    final userId = TokenService.instance.userId ?? 'anonymous';
    return 'encyclopedia_banner_dismissed_$userId';
  }

  Future<void> _loadPremiumBannerState() async {
    // App Store 3.1.1 대응: 프리미엄 게이팅 비활성화 시 배너 노출 안 함
    if (!AppConfig.premiumEnabled) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getBool(_bannerDismissKey) ?? false;
      if (dismissed) return;

      final status = await ref.read(premiumStatusProvider.future);
      if (mounted && status.isFree) {
        setState(() {
          _showPremiumBanner = true;
        });
      }
    } catch (_) {
      // 실패 시 배너 미표시
    }
  }

  Future<void> _dismissPremiumBanner() async {
    setState(() {
      _showPremiumBanner = false;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_bannerDismissKey, true);
    } catch (_) {}
  }

  Future<void> _maybeShowCoachMarks() async {
```
new:
```dart
  Future<void> _maybeShowCoachMarks() async {
```

- [ ] **Step 4: `_buildPremiumBanner` 위젯 메서드 전체 제거 (`/home/premium` push 포함).** Edit:

old:
```dart
  // ── Input area ────────────────────────────────────────────────────

  Widget _buildPremiumBanner() {
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.brandLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_awesome,
            color: AppColors.brandPrimary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.chatbot_premiumBanner,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.nearBlack,
                    height: 1.4,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Semantics(
                  button: true,
                  label: l10n.chatbot_premiumUpgrade,
                  child: GestureDetector(
                  onTap: () async {
                    AnalyticsService.instance.logPremiumFeatureBlocked(
                      feature: 'ai',
                      sourceScreen: 'ai_encyclopedia',
                    );
                    await context.push(
                      '/home/premium?source=ai_banner&feature=ai',
                    );
                    if (!mounted) return;
                    try {
                      final status = await ref.read(premiumStatusProvider.notifier).refreshAndGet();
                      if (!mounted || status.isFree) return;
                      setState(() {
                        _showPremiumBanner = false;
                      });
                    } catch (_) {}
                  },
                  child: Text(
                    l10n.chatbot_premiumUpgrade,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Close',
            child: GestureDetector(
            onTap: _dismissPremiumBanner,
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close, size: 18, color: AppColors.warmGray),
            ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
```
new:
```dart
  // ── Input area ────────────────────────────────────────────────────

  Widget _buildInputArea() {
```

- [ ] **Step 5: 상태 필드 `_showPremiumBanner` 제거.** Edit (읽기/쓰기 참조가 Step 2~4에서 모두 소멸):

old:
```dart
  bool _isSending = false;
  bool _isTyping = false;
  bool _isLoadingMessages = true;
  bool _showPremiumBanner = false;
```
new:
```dart
  bool _isSending = false;
  bool _isTyping = false;
  bool _isLoadingMessages = true;
```

- [ ] **Step 6: 불필요해진 import 4건 제거.** Edit (마지막 사용처가 Step 3~4에서 소멸: `AppConfig`→L155, `TokenService`→L149, `SharedPreferences`→L157·177, `premiumStatusProvider`→L161·1151. `analytics_service`는 `logAiChatSent`, `api_client`는 `ApiException`, `pet_providers`는 `activePetProvider`가 남으므로 유지):

old:
```dart
import '../../../l10n/app_localizations.dart';
import '../../config/app_config.dart';
import '../../models/chat_message.dart';
```
new:
```dart
import '../../../l10n/app_localizations.dart';
import '../../models/chat_message.dart';
```

old:
```dart
import '../../theme/durations.dart';
import '../../providers/premium_provider.dart';
import '../../services/api/api_client.dart';
import '../../services/api/token_service.dart';
import '../../providers/pet_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
```
new:
```dart
import '../../theme/durations.dart';
import '../../services/api/api_client.dart';
import '../../providers/pet_providers.dart';
```

- [ ] **Step 7: 프리미엄 참조 전수 소멸 확인.** Run: `grep -in "premium\|paywall\|/home/premium\|_showPremiumBanner\|logPremiumFeatureBlocked\|SharedPreferences\|TokenService\|AppConfig" /Users/imdonghyeon/perch_care/lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart` → 기대: 출력 0줄. 출력이 있으면 잔여 참조를 제거 후 재확인. 추가 확인: `grep -n "quota_limitReachedMessage" /Users/imdonghyeon/perch_care/lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart` → 기대: 2줄 (SSE·fallback 429 처리).

- [ ] **Step 8: 검증 루프.** Run: `cd /Users/imdonghyeon/perch_care && flutter analyze` → 기대: `No issues found!` (또는 Task 3.1 베이스라인 대비 새 이슈 0건). 실패 시 원인(잔여 참조, unused_import 등) 수정 후 재실행, 통과할 때까지 반복 → 통과 후 커밋:
```bash
cd /Users/imdonghyeon/perch_care && git add lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart && git commit -m "|REMOVE| AI백과 dead 프리미엄 배너 및 프리미엄 참조 전면 제거

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
```

---

**슬라이스 3 참고사항 (조율용):**
- 이 슬라이스 완료 후 `ai_encyclopedia_screen.dart`에는 프리미엄/쿼터 사전 차단 UI가 0건, 서버 429 대응 중립 안내 2건만 남는다.
- l10n 슬라이스는 이 슬라이스의 Task 3.2·3.3 **이후에** `aiEncyclopedia_quotaExhausted`/`aiEncyclopedia_quotaExhaustedHint`/`quotaBadge_normal`/`quotaBadge_exhausted`/`quotaBadge_upgrade`/`chatbot_premiumBanner`/`chatbot_premiumUpgrade` 키를 삭제해야 컴파일이 유지된다.
- `QuotaBadge` 위젯 파일(`lib/src/widgets/quota_badge.dart`) 및 `premium_provider.dart`/`premium_service.dart` 삭제는 타 슬라이스 담당이며, 역시 이 슬라이스 이후여야 한다.
- `AnalyticsService.logQuotaViewed`/`logQuotaReached`/`logPremiumFeatureBlocked` 호출은 이 파일에서 제거됨 — 메서드 정의 삭제는 analytics 담당 슬라이스에서 처리 가능.

---

## Slice 4: home 도메인 isPremium 제거 + 테스트 갱신

> 참고: 슬라이스 공통 중립 l10n 키(`quota_limitReachedTitle`/`quota_limitReachedMessage`)는 home 도메인에 429/403 쿼터 처리 지점이 없어(확인: `home_repository.dart`·`home_screen.dart`에 quota/429 코드 없음) 이 슬라이스에서는 사용처가 없다. 키 신설은 해당 키를 소비하는 슬라이스(ai_encyclopedia/health_check)에서 수행한다.

> 태스크 순서는 참조 소비자(View) → 중간층(State/ViewModel) → 생산자(Repository) 순으로 배열되어 각 태스크 완료 시점에 항상 컴파일 가능하다.

### Task 4.1: HealthSummaryCard isPremium 파라미터 제거 + home_screen 프리미엄 게이트 제거 (View 레이어)
**Files:**
- Modify: `lib/src/widgets/health_summary_card.dart` (L6-17, L72-76, L148)
- Modify: `lib/src/screens/home/home_screen.dart` (L51-53, L233-234, L271-275, L985-986, L1064)

**Interfaces:**
- Produces: `HealthSummaryCard({super.key, required this.summary})` — `isPremium` 파라미터 제거된 새 시그니처. 이 위젯의 유일한 사용처는 `home_screen.dart` L272이며 이 태스크에서 함께 수정 (다른 태스크 의존 없음)
- Consumes: `HomeState.isPremium` — 이 태스크에서 **읽기 제거** (필드 자체는 Task 4.2에서 제거)

- [ ] **Step 1: health_summary_card.dart 클래스 doc·필드·생성자에서 isPremium 제거**

  old:
  ```dart
  /// 건강 변화 요약 카드.
  /// Free: 기본 정보(체중/BHI)만 표시.
  /// Premium: 전체 상세 정보 표시 (이상 소견, 급여/음수 일관성, BHI 추세).
  class HealthSummaryCard extends StatelessWidget {
    final HealthSummary summary;
    final bool isPremium;

    const HealthSummaryCard({
      super.key,
      required this.summary,
      required this.isPremium,
    });
  ```
  new:
  ```dart
  /// 건강 변화 요약 카드.
  /// 기본 정보(체중/BHI)와 상세 정보(이상 소견, 급여/음수 일관성, BHI 추세)를 모두 표시.
  class HealthSummaryCard extends StatelessWidget {
    final HealthSummary summary;

    const HealthSummaryCard({
      super.key,
      required this.summary,
    });
  ```

- [ ] **Step 2: health_summary_card.dart 상세 섹션을 전원 노출로 변경 (L72-76)**

  old:
  ```dart
          // Premium 전용 상세: 프리미엄 유저에게만 노출, free 유저에게는 섹션 자체 비노출
          if (isPremium) ...[
            const Divider(height: 24, color: AppColors.gray150),
            _buildPremiumDetails(l10n),
          ],
  ```
  new:
  ```dart
          // 상세 정보 (이상 소견, 급여/음수 일관성, BHI 추세) — 전원 노출
          const Divider(height: 24, color: AppColors.gray150),
          _buildDetailedMetrics(l10n),
  ```

- [ ] **Step 3: health_summary_card.dart 메서드명 변경 (L148)**

  old:
  ```dart
    Widget _buildPremiumDetails(AppLocalizations l10n) {
  ```
  new:
  ```dart
    Widget _buildDetailedMetrics(AppLocalizations l10n) {
  ```

- [ ] **Step 4: home_screen.dart `_isPremium` 필드 제거 (L51-53)**

  old:
  ```dart
    HealthSummary? _healthSummary;
    PetInsight? _latestInsight;
    bool _isPremium = false;
  ```
  new:
  ```dart
    HealthSummary? _healthSummary;
    PetInsight? _latestInsight;
  ```

- [ ] **Step 5: home_screen.dart build()의 state mirroring에서 isPremium 제거 (L233-234)**

  old:
  ```dart
      _latestInsight = state.insight;
      _isPremium = state.isPremium;
  ```
  new:
  ```dart
      _latestInsight = state.insight;
  ```

- [ ] **Step 6: home_screen.dart HealthSummaryCard 호출부에서 isPremium 전달 제거 (L271-275)**

  old:
  ```dart
                                if (_healthSummary != null)
                                  HealthSummaryCard(
                                    summary: _healthSummary!,
                                    isPremium: _isPremium,
                                  ),
  ```
  new:
  ```dart
                                if (_healthSummary != null)
                                  HealthSummaryCard(
                                    summary: _healthSummary!,
                                  ),
  ```

- [ ] **Step 7: home_screen.dart 인사이트 섹션 프리미엄 게이트 제거 → 전원 노출 (L985-986)**

  old:
  ```dart
      // Premium 사용자 + 인사이트 있음
      if (_isPremium && _latestInsight != null) {
  ```
  new:
  ```dart
      // 인사이트가 있으면 전원 노출
      if (_latestInsight != null) {
  ```

- [ ] **Step 8: home_screen.dart 인사이트 없음 분기의 프리미엄 언급 주석 정리 (L1064-1065)**

  old:
  ```dart
      // Free 사용자에게는 인사이트 티저 카드 표시 안 함 (App Store 3.1.1 대응 — 업그레이드 CTA 제거)
      return const SizedBox.shrink();
  ```
  new:
  ```dart
      // 인사이트가 아직 없으면 섹션 미표시
      return const SizedBox.shrink();
  ```

- [ ] **Step 9: 검증 루프 + 커밋**
  Run: `flutter analyze` → 기대 출력: `No issues found!` (실패 시 원인 수정 후 재실행, 통과할 때까지 반복). 통과 후:
  ```bash
  git add lib/src/widgets/health_summary_card.dart lib/src/screens/home/home_screen.dart
  git commit -m "|REMOVE| home View 레이어 isPremium 게이트 제거 — HealthSummaryCard 상세·주간 인사이트 전원 노출

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
  ```

### Task 4.2: HomeState.isPremium 필드 제거 + HomeViewModel 전달 제거 + 테스트 검증 제거
**Files:**
- Modify: `lib/src/view_models/home/home_state.dart` (L15-16, L36-37, L51-53, L65-67)
- Modify: `lib/src/view_models/home/home_view_model.dart` (L62-68)
- Modify: `test/view_models/home/home_view_model_test.dart` (L103-105)

**Interfaces:**
- Produces: `HomeState` — `isPremium` 필드/생성자 파라미터/copyWith 파라미터 제거된 새 형태. Task 4.1이 선행되어 View의 읽기가 이미 제거됨
- Consumes: `HomeDerivedData.isPremium` — 이 태스크에서 **읽기 제거** (필드 자체는 Task 4.3에서 제거. 테스트의 `HomeDerivedData(isPremium: true)` 생성자 호출은 Task 4.3까지 유효하므로 이 태스크에서는 유지)

- [ ] **Step 1: home_state.dart 필드 선언에서 isPremium 제거 (L15-16)**

  old:
  ```dart
    final PetInsight? insight;
    final bool isPremium;
  ```
  new:
  ```dart
    final PetInsight? insight;
  ```

- [ ] **Step 2: home_state.dart 생성자에서 isPremium 제거 (L36-38)**

  old:
  ```dart
      this.insight,
      this.isPremium = false,
      this.isBhiLoading = false,
  ```
  new:
  ```dart
      this.insight,
      this.isBhiLoading = false,
  ```

- [ ] **Step 3: home_state.dart copyWith 시그니처에서 isPremium 제거 (L51-53)**

  old:
  ```dart
      PetInsight? insight,
      bool? isPremium,
      bool? isBhiLoading,
  ```
  new:
  ```dart
      PetInsight? insight,
      bool? isBhiLoading,
  ```

- [ ] **Step 4: home_state.dart copyWith 본문에서 isPremium 제거 (L65-67)**

  old:
  ```dart
        insight: insight ?? this.insight,
        isPremium: isPremium ?? this.isPremium,
        isBhiLoading: isBhiLoading ?? this.isBhiLoading,
  ```
  new:
  ```dart
        insight: insight ?? this.insight,
        isBhiLoading: isBhiLoading ?? this.isBhiLoading,
  ```

- [ ] **Step 5: home_view_model.dart 파생 데이터 반영에서 isPremium 전달 제거 (L63-68)**

  old:
  ```dart
        final derived = await _repo.loadHealthDerivedData(pet.id);
        next = next.copyWith(
          healthSummary: derived.healthSummary,
          insight: derived.insight,
          isPremium: derived.isPremium,
        );
  ```
  new:
  ```dart
        final derived = await _repo.loadHealthDerivedData(pet.id);
        next = next.copyWith(
          healthSummary: derived.healthSummary,
          insight: derived.insight,
        );
  ```

- [ ] **Step 6: home_view_model_test.dart state.isPremium 검증 제거 (L103-105)**

  old:
  ```dart
        expect(state.hasWater, isFalse);
        expect(state.isPremium, isTrue);
        expect(state.isBhiOffline, isFalse);
  ```
  new:
  ```dart
        expect(state.hasWater, isFalse);
        expect(state.isBhiOffline, isFalse);
  ```

- [ ] **Step 7: 검증 루프 + 커밋**
  Run: `flutter analyze` → 기대 출력: `No issues found!`. 이어서 `flutter test test/view_models/home/` → 기대 출력: `All tests passed!` (4개 테스트). 실패 시 원인 수정 후 재실행, 통과할 때까지 반복. 통과 후:
  ```bash
  git add lib/src/view_models/home/home_state.dart lib/src/view_models/home/home_view_model.dart test/view_models/home/home_view_model_test.dart
  git commit -m "|REMOVE| HomeState/HomeViewModel isPremium 필드·전달 제거

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
  ```

### Task 4.3: HomeRepository PremiumService 의존 제거 — weekly insight 항상 조회
**Files:**
- Modify: `lib/src/repositories/home_repository.dart` (L11, L15-19, L40-41, L66-77, L79-102, L158-186)
- Modify: `test/view_models/home/home_view_model_test.dart` (L90-91)

**Interfaces:**
- Produces: `HomeDerivedData({this.healthSummary, this.insight})` — `isPremium` 필드 제거된 새 시그니처. `HomeRepositoryImpl` 생성자에서 `premiumService` named 파라미터 제거 (호출부 `repository_providers.dart:19`는 `HomeRepositoryImpl()` 무인자 호출이므로 수정 불필요 — 확인 완료)
- Consumes: 없음 (Task 4.2 선행으로 `derived.isPremium` 읽기 이미 제거됨)

- [ ] **Step 1: home_repository.dart PremiumService import 제거 (L10-12)**

  old:
  ```dart
  import '../services/pet/pet_service.dart';
  import '../services/premium/premium_service.dart';
  import '../services/sync/sync_service.dart';
  ```
  new:
  ```dart
  import '../services/pet/pet_service.dart';
  import '../services/sync/sync_service.dart';
  ```

- [ ] **Step 2: 클래스 doc 주석에서 Premium 언급 제거 (L15-19)**

  old:
  ```dart
  /// 홈 화면 전용 aggregated data fetcher.
  ///
  /// 홈 화면은 Pet + BHI + HealthSummary + Insight + Premium 상태 + 오프라인 로컬 데이터
  /// 유무까지 한 화면에서 필요로 한다. 이를 각각 다른 ViewModel에서 구독시키지 않고
  /// HomeRepository가 묶어서 제공하여 HomeViewModel이 단일 의존으로 처리하도록 한다.
  ```
  new:
  ```dart
  /// 홈 화면 전용 aggregated data fetcher.
  ///
  /// 홈 화면은 Pet + BHI + HealthSummary + Insight + 오프라인 로컬 데이터
  /// 유무까지 한 화면에서 필요로 한다. 이를 각각 다른 ViewModel에서 구독시키지 않고
  /// HomeRepository가 묶어서 제공하여 HomeViewModel이 단일 의존으로 처리하도록 한다.
  ```

- [ ] **Step 3: abstract 메서드 doc 갱신 (L40-41)**

  old:
  ```dart
    /// 건강 요약 + (Premium인 경우) 주간 인사이트 + Premium 상태 병렬 로드.
    Future<HomeDerivedData> loadHealthDerivedData(String petId);
  ```
  new:
  ```dart
    /// 건강 요약 + 주간 인사이트 로드.
    Future<HomeDerivedData> loadHealthDerivedData(String petId);
  ```

- [ ] **Step 4: HomeDerivedData에서 isPremium 필드 제거 (L66-77)**

  old:
  ```dart
  /// 건강 요약/인사이트/프리미엄 상태의 한 번에 묶인 응답.
  class HomeDerivedData {
    final HealthSummary? healthSummary;
    final PetInsight? insight;
    final bool isPremium;

    const HomeDerivedData({
      this.healthSummary,
      this.insight,
      this.isPremium = false,
    });
  }
  ```
  new:
  ```dart
  /// 건강 요약/인사이트의 한 번에 묶인 응답.
  class HomeDerivedData {
    final HealthSummary? healthSummary;
    final PetInsight? insight;

    const HomeDerivedData({
      this.healthSummary,
      this.insight,
    });
  }
  ```

- [ ] **Step 5: HomeRepositoryImpl 생성자·필드에서 PremiumService 제거 (L80-100)**

  old:
  ```dart
    HomeRepositoryImpl({
      PetService? petService,
      PetLocalCacheService? petCache,
      BhiService? bhiService,
      PremiumService? premiumService,
      ApiClient? apiClient,
      WeightService? weightService,
      SyncService? syncService,
    })  : _petService = petService ?? PetService.instance,
          _petCache = petCache ?? PetLocalCacheService.instance,
          _bhiService = bhiService ?? BhiService.instance,
          _premiumService = premiumService ?? PremiumService.instance,
          _api = apiClient ?? ApiClient.instance,
          _weightService = weightService ?? WeightService.instance,
          _syncService = syncService ?? SyncService.instance;

    final PetService _petService;
    final PetLocalCacheService _petCache;
    final BhiService _bhiService;
    final PremiumService _premiumService;
    final ApiClient _api;
  ```
  new:
  ```dart
    HomeRepositoryImpl({
      PetService? petService,
      PetLocalCacheService? petCache,
      BhiService? bhiService,
      ApiClient? apiClient,
      WeightService? weightService,
      SyncService? syncService,
    })  : _petService = petService ?? PetService.instance,
          _petCache = petCache ?? PetLocalCacheService.instance,
          _bhiService = bhiService ?? BhiService.instance,
          _api = apiClient ?? ApiClient.instance,
          _weightService = weightService ?? WeightService.instance,
          _syncService = syncService ?? SyncService.instance;

    final PetService _petService;
    final PetLocalCacheService _petCache;
    final BhiService _bhiService;
    final ApiClient _api;
  ```

- [ ] **Step 6: loadHealthDerivedData — getTier 병렬 호출 제거, insight 항상 조회 (L158-186)**

  old:
  ```dart
    @override
    Future<HomeDerivedData> loadHealthDerivedData(String petId) async {
      final tierFuture = _premiumService.getTier();
      final summaryFuture = _api.get('/pets/$petId/health-summary');
      final results = await Future.wait<dynamic>([tierFuture, summaryFuture]);

      final status = results[0] as PremiumStatus;
      final summaryJson = results[1] as Map<String, dynamic>;
      final summary = HealthSummary.fromJson(summaryJson);

      PetInsight? insight;
      if (status.isPremium) {
        try {
          final insightJson =
              await _api.get('/pets/$petId/insights?type=weekly');
          if (insightJson != null) {
            insight = PetInsight.fromJson(insightJson as Map<String, dynamic>);
          }
        } catch (_) {
          // 인사이트 실패는 무시 (홈 화면의 다른 데이터는 유효)
        }
      }

      return HomeDerivedData(
        healthSummary: summary,
        insight: insight,
        isPremium: status.isPremium,
      );
    }
  ```
  new:
  ```dart
    @override
    Future<HomeDerivedData> loadHealthDerivedData(String petId) async {
      final summaryJson =
          await _api.get('/pets/$petId/health-summary') as Map<String, dynamic>;
      final summary = HealthSummary.fromJson(summaryJson);

      // 주간 인사이트는 항상 조회 (프리미엄 게이트 제거)
      PetInsight? insight;
      try {
        final insightJson =
            await _api.get('/pets/$petId/insights?type=weekly');
        if (insightJson != null) {
          insight = PetInsight.fromJson(insightJson as Map<String, dynamic>);
        }
      } catch (_) {
        // 인사이트 실패는 무시 (홈 화면의 다른 데이터는 유효)
      }

      return HomeDerivedData(
        healthSummary: summary,
        insight: insight,
      );
    }
  ```

- [ ] **Step 7: home_view_model_test.dart mock에서 isPremium 인자 제거 (L90-91)**

  old:
  ```dart
        when(() => repo.loadHealthDerivedData(any()))
            .thenAnswer((_) async => const HomeDerivedData(isPremium: true));
  ```
  new:
  ```dart
        when(() => repo.loadHealthDerivedData(any()))
            .thenAnswer((_) async => const HomeDerivedData());
  ```

- [ ] **Step 8: 검증 루프 + 커밋**
  Run: `flutter analyze` → 기대 출력: `No issues found!`. 이어서 `flutter test test/view_models/home/` → 기대 출력: `All tests passed!`. 실패 시 원인 수정 후 재실행, 통과할 때까지 반복. 통과 후:
  ```bash
  git add lib/src/repositories/home_repository.dart test/view_models/home/home_view_model_test.dart
  git commit -m "|REMOVE| HomeRepository PremiumService 의존 제거 — weekly insight 항상 조회

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
  ```

### Task 4.4: models_serialization_test.dart HealthSummary 테스트 명칭 정리
**Files:**
- Modify: `test/models/models_serialization_test.dart` (L1075)

**Interfaces:** 없음 (테스트 명칭만 변경 — `HealthSummary` 모델의 `abnormalCount`/`foodConsistency`/`waterConsistency`/`bhiTrend`/`bhiPrevious` 필드는 유지되며 이제 전원 노출 상세 정보로 사용됨)

- [ ] **Step 1: 테스트 이름에서 'Premium' 표현을 중립 표현으로 변경 (L1075)**

  old:
  ```dart
      test('fromJson nullable Premium 필드 null 처리', () {
  ```
  new:
  ```dart
      test('fromJson nullable 상세 필드 null 처리', () {
  ```

- [ ] **Step 2: 검증 루프 + 커밋**
  Run: `flutter analyze` → 기대 출력: `No issues found!`. 이어서 `flutter test test/models/models_serialization_test.dart` → 기대 출력: `All tests passed!`. 실패 시 원인 수정 후 재실행, 통과할 때까지 반복. 통과 후:
  ```bash
  git add test/models/models_serialization_test.dart
  git commit -m "|REMOVE| HealthSummary 직렬화 테스트 명칭 중립화 — Premium 표현 제거 (모델 필드는 유지)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
  ```

---

## 슬라이스 1: 앱 코어 — 프리미엄 배선 제거 + 파일 삭제 + 라우터

**슬라이스 전제 및 순서 결정 (grep 전수 확인 결과)**
- `AppConfig.premiumEnabled` 읽는 곳: `premium_screen.dart` 3곳(L2·52·88 — Task 1.5에서 파일째 삭제) + `ai_encyclopedia_screen.dart:155`(ai_encyclopedia 슬라이스 담당). 따라서 **app_config 태스크(1.6)는 파일 삭제(1.5)보다도 뒤, 이 슬라이스의 진짜 마지막**으로 배치한다.
- 삭제 대상 7파일의 잔존 참조(이 슬라이스 외): `health_check_main/capture/analyzing/vet_summary/history` 5화면(health_check 슬라이스), `ai_encyclopedia_screen.dart`(ai_encyclopedia 슬라이스), `home_repository.dart`(home 슬라이스). **Task 1.5·1.6은 해당 슬라이스 태스크 완료 후에만 실행 가능.**
- 중립 l10n 키(`quota_limitReachedTitle`/`quota_limitReachedMessage`)는 이 슬라이스에서 소비하지 않음 — 키 신설·사용은 health_check/ai_encyclopedia 슬라이스 태스크 소관.
- 환경 주의: 현재 로컬 Flutter SDK의 `analysis_server.dart.snapshot`이 손상되어 `flutter analyze`가 tool crash로 실패할 수 있음. 이 경우 `rm -rf ~/flutter/bin/cache && flutter doctor`로 SDK 캐시 재생성 후 analyze를 재실행한다 (1회만 필요).

---

### Task 1.1: splash_screen — premiumStatusProvider 시딩 + IapService 초기화 제거
**Files:** Modify: `lib/src/screens/splash/splash_screen.dart` (L12, L15, L131-134, L363-367)
**Interfaces:** Consumes: 없음 / Produces: 없음 (배선 제거만)
**의존성:** 없음 — 즉시 실행 가능

- [ ] **Step 1: import 2줄 제거** — `lib/src/screens/splash/splash_screen.dart` L10-16:

old:
```dart
import '../../models/pet.dart';
import '../../providers/pet_providers.dart';
import '../../providers/premium_provider.dart';
import '../../services/api/api_client.dart';
import '../../services/api/token_service.dart';
import '../../services/iap/iap_service.dart';
import '../../services/push/push_notification_service.dart';
```
new:
```dart
import '../../models/pet.dart';
import '../../providers/pet_providers.dart';
import '../../services/api/api_client.dart';
import '../../services/api/token_service.dart';
import '../../services/push/push_notification_service.dart';
```

- [ ] **Step 2: premiumStatusProvider 시딩 제거** — 같은 파일 `_initializeServices()` 내부 (L131-134):

old:
```dart
        await ref.read(activePetProvider.notifier).refresh();
        await ref.read(petListProvider.notifier).refresh();
        await ref.read(premiumStatusProvider.notifier).refresh();
        debugPrint('[Splash] Riverpod providers seeded');
```
new:
```dart
        await ref.read(activePetProvider.notifier).refresh();
        await ref.read(petListProvider.notifier).refresh();
        debugPrint('[Splash] Riverpod providers seeded');
```

- [ ] **Step 3: IapService.initialize 호출 제거** — 같은 파일 `_navigateToInitialRoute()` 내부 (L363-367):

old:
```dart
    // 로그인 상태면 FCM 푸시 토큰 등록 + IAP 초기화
    if (isLoggedIn) {
      unawaited(PushNotificationService.instance.initialize());
      await IapService.instance.initialize();
    }
```
new:
```dart
    // 로그인 상태면 FCM 푸시 토큰 등록
    if (isLoggedIn) {
      unawaited(PushNotificationService.instance.initialize());
    }
```

- [ ] **Step 4: 검증 루프 + 커밋** — Run: `flutter analyze` → 기대 출력: `No issues found!` (신규 이슈 0건). 실패 시 원인 수정 후 재실행, 통과할 때까지 반복 → 통과 후 커밋:
```bash
git add lib/src/screens/splash/splash_screen.dart
git commit -m "|REMOVE| splash — premiumStatusProvider 시딩·IapService 초기화 제거

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
```

---

### Task 1.2: auth_service — IAP/Premium 수명주기 호출 제거
**Files:** Modify: `lib/src/services/auth/auth_service.dart` (L7, L13, L198-201, L214-228, L326-329)
**Interfaces:** Consumes: 없음 / Produces: 없음 (`signOut()`/`deleteAccount()` 시그니처 불변 — 다른 슬라이스 영향 없음)
**의존성:** 없음 — 즉시 실행 가능 (1.1과 순서 무관)

- [ ] **Step 1: premium_service import 제거** — `lib/src/services/auth/auth_service.dart` L5-8:

old:
```dart
import '../pet/pet_local_cache_service.dart';
import '../pet/pet_service.dart';
import '../premium/premium_service.dart';
import '../weight/weight_service.dart';
```
new:
```dart
import '../pet/pet_local_cache_service.dart';
import '../pet/pet_service.dart';
import '../weight/weight_service.dart';
```

- [ ] **Step 2: iap_service import 제거** — 같은 파일 L12-14:

old:
```dart
import '../analytics/analytics_service.dart';
import '../iap/iap_service.dart';
import '../push/push_notification_service.dart';
```
new:
```dart
import '../analytics/analytics_service.dart';
import '../push/push_notification_service.dart';
```

- [ ] **Step 3: 로그인 후 IAP 초기화 제거** — 같은 파일 `_initializeAuthenticatedServices()` (L198-201):

old:
```dart
  Future<void> _initializeAuthenticatedServices() async {
    unawaited(PushNotificationService.instance.initialize());
    await IapService.instance.initialize();
  }
```
new:
```dart
  Future<void> _initializeAuthenticatedServices() async {
    unawaited(PushNotificationService.instance.initialize());
  }
```

- [ ] **Step 4: signOut의 PremiumService 캐시 무효화 + IapService.dispose 제거** — 같은 파일 `signOut()` (L214-228). 주의: `// 인메모리 캐시 무효화` 블록은 `deleteAccount()`에도 동일 텍스트로 존재하므로 반드시 아래의 확장 블록 전체로 매칭할 것:

old:
```dart
    // 인메모리 캐시 무효화
    PetService.instance.invalidateCache();
    PremiumService.instance.invalidateCache();
    WeightService.instance.clearAllRecords();

    // 로컬 스토리지 정리
    await _petCache.clearAll();
    await LocalImageStorageService.instance.clearAll();
    await HealthCheckStorageService.instance.clearAll();
    await ChatStorageService.instance.clearAllMessages();
    await CoachMarkService.instance.clearAll();
    await PushNotificationService.instance.dispose();
    IapService.instance.dispose();
    await _tokenService.clearTokens();
    _lastHasPets = null;
```
new:
```dart
    // 인메모리 캐시 무효화
    PetService.instance.invalidateCache();
    WeightService.instance.clearAllRecords();

    // 로컬 스토리지 정리
    await _petCache.clearAll();
    await LocalImageStorageService.instance.clearAll();
    await HealthCheckStorageService.instance.clearAll();
    await ChatStorageService.instance.clearAllMessages();
    await CoachMarkService.instance.clearAll();
    await PushNotificationService.instance.dispose();
    await _tokenService.clearTokens();
    _lastHasPets = null;
```

- [ ] **Step 5: deleteAccount의 PremiumService 캐시 무효화 제거** — 같은 파일 `deleteAccount()` (L326-329, Step 4 적용 후 유일 매칭):

old:
```dart
    // 인메모리 캐시 무효화
    PetService.instance.invalidateCache();
    PremiumService.instance.invalidateCache();
    WeightService.instance.clearAllRecords();
```
new:
```dart
    // 인메모리 캐시 무효화
    PetService.instance.invalidateCache();
    WeightService.instance.clearAllRecords();
```

- [ ] **Step 6: 검증 루프 + 커밋** — Run: `flutter analyze` → 기대 출력: `No issues found!` (신규 이슈 0건). 실패 시 원인 수정 후 재실행, 통과할 때까지 반복 → 통과 후 커밋:
```bash
git add lib/src/services/auth/auth_service.dart
git commit -m "|REMOVE| auth_service — IAP 초기화·dispose 및 PremiumService 캐시 무효화 제거

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
```

---

### Task 1.3: auth_actions — premiumStatusProvider invalidate 제거
**Files:** Modify: `lib/src/providers/auth_actions.dart` (전체 15줄 — L4 import, L12 invalidate)
**Interfaces:** Consumes: 없음 / Produces: `performLogout(WidgetRef ref)` 시그니처 불변 (Stage 4에서 ViewModel로 승격 예정이나 이 슬라이스에서는 유지)
**의존성:** 없음 — 즉시 실행 가능

- [ ] **Step 1: 파일 전체 교체** — `lib/src/providers/auth_actions.dart`:

old (파일 전체):
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth/auth_service.dart';
import 'pet_providers.dart';
import 'premium_provider.dart';
import 'bhi_provider.dart';

/// 로그아웃 시 Riverpod 상태 일괄 리셋
Future<void> performLogout(WidgetRef ref) async {
  await AuthService.instance.signOut();
  ref.invalidate(activePetProvider);
  ref.invalidate(petListProvider);
  ref.invalidate(premiumStatusProvider);
  ref.invalidate(bhiProvider);
}
```
new (파일 전체):
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth/auth_service.dart';
import 'pet_providers.dart';
import 'bhi_provider.dart';

/// 로그아웃 시 Riverpod 상태 일괄 리셋
Future<void> performLogout(WidgetRef ref) async {
  await AuthService.instance.signOut();
  ref.invalidate(activePetProvider);
  ref.invalidate(petListProvider);
  ref.invalidate(bhiProvider);
}
```

- [ ] **Step 2: 검증 루프 + 커밋** — Run: `flutter analyze` → 기대 출력: `No issues found!` (신규 이슈 0건). 실패 시 원인 수정 후 재실행, 통과할 때까지 반복 → 통과 후 커밋:
```bash
git add lib/src/providers/auth_actions.dart
git commit -m "|REMOVE| auth_actions — premiumStatusProvider invalidate 제거

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
```

---

### Task 1.4: 라우터 — premium 라우트·이름·경로 상수 제거
**Files:** Modify: `lib/src/router/app_router.dart` (L40, L217-224), `lib/src/router/route_names.dart` (L33-34), `lib/src/router/route_paths.dart` (L41-43)
**Interfaces:** Consumes: 없음 / Produces: **`RouteNames.premium`·`RoutePaths.premium` 심볼 소멸.** grep 확인 결과 두 상수의 사용처는 app_router.dart 내부뿐 — 컴파일 의존 없음. 단, `health_check_main_screen.dart:148`·`ai_encyclopedia_screen.dart:1147`이 raw string `'/home/premium'`을 push하므로 이 태스크 이후 해당 버튼은 런타임 404가 됨 (컴파일은 정상). health_check/ai_encyclopedia 슬라이스가 push 코드 자체를 제거하면 해소.
**의존성:** 없음 — 즉시 실행 가능. 단, Task 1.5(premium_screen.dart 삭제)의 **선행 필수 태스크**.

- [ ] **Step 1: premium GoRoute 제거** — `lib/src/router/app_router.dart` L212-224:

old:
```dart
                  GoRoute(
                    path: 'faq',
                    name: RouteNames.faq,
                    builder: (context, state) => const FaqScreen(),
                  ),
                  GoRoute(
                    path: 'premium',
                    name: RouteNames.premium,
                    builder: (context, state) => PremiumScreen(
                      source: state.uri.queryParameters['source'],
                      feature: state.uri.queryParameters['feature'],
                    ),
                  ),
```
new:
```dart
                  GoRoute(
                    path: 'faq',
                    name: RouteNames.faq,
                    builder: (context, state) => const FaqScreen(),
                  ),
```

- [ ] **Step 2: premium_screen import 제거** — 같은 파일 L39-41:

old:
```dart
import '../screens/faq/faq_screen.dart';
import '../screens/premium/premium_screen.dart';
import '../data/terms_content.dart';
```
new:
```dart
import '../screens/faq/faq_screen.dart';
import '../data/terms_content.dart';
```

- [ ] **Step 3: RouteNames.premium 제거** — `lib/src/router/route_names.dart` L32-36:

old:
```dart
  static const String termsDetailPublic = 'terms-detail-public';
  // 프리미엄
  static const String premium = 'premium';
  // 건강체크
  static const String healthCheck = 'health-check';
```
new:
```dart
  static const String termsDetailPublic = 'terms-detail-public';
  // 건강체크
  static const String healthCheck = 'health-check';
```

- [ ] **Step 4: RoutePaths.premium 제거** — `lib/src/router/route_paths.dart` L41-44:

old:
```dart
  // 프리미엄 (full: /home/premium)
  static const String premium = '/home/premium';

  // 건강체크 하위 경로 (full: /home/health-check/...)
```
new:
```dart
  // 건강체크 하위 경로 (full: /home/health-check/...)
```

- [ ] **Step 5: 검증 루프 + 커밋** — Run: `flutter analyze` → 기대 출력: `No issues found!` (신규 이슈 0건). 실패 시 원인 수정 후 재실행, 통과할 때까지 반복 → 통과 후 커밋:
```bash
git add lib/src/router/app_router.dart lib/src/router/route_names.dart lib/src/router/route_paths.dart
git commit -m "|REMOVE| router — premium GoRoute·RouteNames·RoutePaths 제거

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
```

---

### Task 1.5: 프리미엄 전용 파일 7개 삭제 (계획상 최후반 배치)
**Files:** Delete: `lib/src/services/premium/premium_service.dart`, `lib/src/services/iap/iap_service.dart`, `lib/src/providers/premium_provider.dart`, `lib/src/screens/premium/premium_screen.dart`, `lib/src/screens/premium/promo_code_bottom_sheet.dart`, `lib/src/widgets/quota_badge.dart`, `lib/src/widgets/sns_event_card.dart`
**Interfaces:** Consumes: 없음 / Produces: `PremiumService`·`IapService`·`premiumStatusProvider`·`PremiumScreen`·`PromoCodeBottomSheet`·`QuotaBadge`·`VisionQuotaBadge`·`SnsEventCard`·`PremiumStatus`·`EncyclopediaQuota`·`VisionQuota` 심볼 전체 소멸 — 이후 어떤 태스크도 이 심볼들을 참조할 수 없음
**의존성 (전부 선행 필수):** Task 1.1(splash)·1.2(auth_service)·1.3(auth_actions)·1.4(router) + **다른 슬라이스의 화면/레포지토리 참조 제거 태스크**: health_check 5화면(`health_check_main/capture/analyzing/vet_summary/history`), `ai_encyclopedia_screen.dart`, `home_repository.dart`(home 슬라이스). 이 전제가 계획상 이 태스크가 마지막 배치인 이유다.

- [ ] **Step 1: 잔존 참조 0건 게이트 (필수 — 통과 전 삭제 금지)** — Run:
```bash
grep -rn "premium_service\.dart\|iap_service\.dart\|premium_provider\.dart\|premium_screen\.dart\|promo_code_bottom_sheet\.dart\|quota_badge\.dart\|sns_event_card\.dart\|PremiumService\|IapService\|premiumStatusProvider\|QuotaBadge\|VisionQuotaBadge\|PromoCodeBottomSheet\|SnsEventCard\|PremiumScreen\|PremiumStatus\|EncyclopediaQuota\|VisionQuota" lib test --include="*.dart" \
  | grep -v "lib/src/services/premium/premium_service.dart\|lib/src/services/iap/iap_service.dart\|lib/src/providers/premium_provider.dart\|lib/src/screens/premium/\|lib/src/widgets/quota_badge.dart\|lib/src/widgets/sns_event_card.dart"
```
기대 출력: **없음 (exit code 1)**. 출력이 있으면 그 파일을 담당하는 선행 태스크(위 의존성 목록)가 미완료 상태 — 이 태스크를 중단하고 해당 태스크를 먼저 완료한다. 절대 이 태스크 안에서 임시방편 수정하지 않는다.
- [ ] **Step 2: 7개 파일 git rm** — Run:
```bash
git rm lib/src/services/premium/premium_service.dart lib/src/services/iap/iap_service.dart lib/src/providers/premium_provider.dart lib/src/screens/premium/premium_screen.dart lib/src/screens/premium/promo_code_bottom_sheet.dart lib/src/widgets/quota_badge.dart lib/src/widgets/sns_event_card.dart
```
기대: 7건 `rm '...'` 출력, `lib/src/screens/premium/`·`lib/src/services/premium/`·`lib/src/services/iap/` 디렉토리는 비면서 자동 소멸.
- [ ] **Step 3: 검증 루프 + 커밋** — Run: `flutter analyze` → 기대 출력: `No issues found!` (신규 이슈 0건). 이어서 `flutter test` → 기대: `All tests passed!`. 실패 시 원인 수정(참조 누락이면 Step 1로 복귀) 후 재실행, 통과할 때까지 반복 → 통과 후 커밋 (git rm이 이미 스테이징했으므로 add 불필요):
```bash
git commit -m "|REMOVE| 프리미엄 전용 파일 7개 삭제 — premium/iap 서비스·provider·화면·위젯

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
```

---

### Task 1.6: app_config — premiumEnabled 플래그 제거 (슬라이스 1 최종 태스크)
**Files:** Modify: `lib/src/config/app_config.dart` (L7-9)
**Interfaces:** Consumes: 없음 / Produces: `AppConfig.premiumEnabled` 심볼 소멸 (`AppConfig.authRedirectUri`는 유지)
**의존성 (grep 전수 확인으로 확정된 순서):** `premiumEnabled` 읽는 곳은 ① `premium_screen.dart` L2·52·88 → **Task 1.5에서 파일 삭제로 해소**, ② `ai_encyclopedia_screen.dart:155` → **ai_encyclopedia 슬라이스 태스크에서 제거**. 따라서 이 태스크는 Task 1.5와 ai_encyclopedia 슬라이스 완료 후에만 실행 — Task 1.5보다도 뒤인 이유.

- [ ] **Step 1: 사용처 0건 게이트** — Run: `grep -rn "premiumEnabled" lib test --include="*.dart"` → 기대 출력: `lib/src/config/app_config.dart` 정의부 1줄만. 다른 파일이 나오면 중단하고 해당 슬라이스 태스크 먼저 완료.
- [ ] **Step 2: 플래그 제거** — `lib/src/config/app_config.dart`:

old (파일 전체):
```dart
/// App-wide compile-time configuration.
class AppConfig {
  AppConfig._();

  static const String authRedirectUri = 'perchcare://auth-callback';

  /// false로 설정하면 프리미엄 게이팅 비활성화 (App Store 리뷰용).
  /// IAP 준비 완료 시 true로 변경.
  static const bool premiumEnabled = false;
}
```
new (파일 전체):
```dart
/// App-wide compile-time configuration.
class AppConfig {
  AppConfig._();

  static const String authRedirectUri = 'perchcare://auth-callback';
}
```

- [ ] **Step 3: 검증 루프 + 커밋** — Run: `flutter analyze` → 기대 출력: `No issues found!` (신규 이슈 0건). 실패 시 원인 수정 후 재실행, 통과할 때까지 반복 → 통과 후 커밋:
```bash
git add lib/src/config/app_config.dart
git commit -m "|REMOVE| app_config — premiumEnabled 플래그 제거

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA"
```

---

**슬라이스 1 태스크 의존성 요약**
| 태스크 | 선행 조건 |
|---|---|
| 1.1 splash | 없음 |
| 1.2 auth_service | 없음 |
| 1.3 auth_actions | 없음 |
| 1.4 router | 없음 (1.5의 선행 필수) |
| 1.5 파일 7개 삭제 | 1.1 + 1.2 + 1.3 + 1.4 + health_check 슬라이스 5화면 + ai_encyclopedia 슬라이스 + home 슬라이스(home_repository) |
| 1.6 app_config | 1.5 + ai_encyclopedia 슬라이스 (premiumEnabled 읽는 곳 전멸 후) |
