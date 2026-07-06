# Stage 2 — Weight 도메인 MVVM 완성 + Pet 구멍 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** weight 도메인(weight_detail_screen 2,561줄 + weight_record_screen 잔여 조회)을 Repository/ViewModel 경유로 완전 전환하고, pet 도메인의 마지막 우회(pet_profile_detail_screen)를 기존 PetRepository/PetAddViewModel로 흡수한다.

**Architecture:** 기존 MVVM 5-layer(View→ViewModel→Repository→Service→Model)를 따른다. Schedule/DailyRecord는 Repository 레이어가 없으므로 신설한다. weight_detail_screen은 3개 도메인 데이터(체중/일정/일일기록)+활성펫 동기화를 aggregate하는 `WeightDetailViewModel extends AsyncNotifier<WeightDetailState>`로 전환하되, 기존 화면의 미묘한 동작(월 변경 시 부분 리로드, 일정 낙관적 삭제, 일일기록 리로드 삭제, provider→로컬 단방향 활성펫 가드)을 **그대로 보존**한다. pet 구멍은 신규 코드를 만들지 않고 이미 완성된 `PetAddViewModel.save()` + 신규 `ActivePetViewModel.deletePet()`로 흡수한다.

**Tech Stack:** Flutter, flutter_riverpod (AsyncNotifier/AsyncNotifierProvider), mocktail + ProviderContainer 단위 테스트.

## Global Constraints

- **behavior-preserving 원칙**: weight_detail 전환은 순수 구조 변경. UI/네트워크 동작·에러 스낵바·리로드 규칙·낙관적 삭제 시맨틱을 바꾸지 않는다.
- **오프라인 큐 미도입**: Schedule/DailyRecord는 현재 실패=에러 스낵바(오프라인 큐 없음). SyncService에 신규 type 핸들러를 추가하지 않으므로 Repository는 서비스 래핑 + 에러 전파만 한다. `enqueue`를 호출하지 않는다(호출하면 큐가 영원히 안 빠짐).
- **레거시 provider alias 유지**: `activePetProvider`(=activePetViewModelProvider) 등 기존 이름 유지.
- **CoachMarkService / AnalyticsService는 View/VM 직접 호출 허용**(cross-cutting 예외). 이번 전환에서 provider로 감싸지 않는다.
- **`AsyncViewModel` base에는 `runLoad`만 존재**(CLAUDE.md의 runAction 언급은 오기). 세밀 갱신형 VM은 `AsyncNotifier<T>`를 직접 상속하고 수동 state 관리(HomeViewModel 선례). 전체 리로드형은 `AsyncViewModel<T>` + runLoad.
- **테스트 패턴**: `class MockXxx extends Mock implements Xxx {}` + `ProviderContainer(overrides:[xxxProvider.overrideWithValue(mock)])` + `addTearDown(container.dispose)` + `await container.read(provider.future)` 후 action. 비프리미티브 any()는 `registerFallbackValue(Fake)`.
- **완료 게이트(매 커밋 전)**: `flutter analyze`(신규 이슈 0) + `flutter test`(전체 통과).
- 커밋 푸터:
  ```
  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA
  ```

---

## File Structure

**신규 파일:**
- `lib/src/repositories/schedule_repository.dart` — ScheduleRepository (abstract+Impl). 실사용 3메서드만 노출.
- `lib/src/repositories/daily_record_repository.dart` — DailyRecordRepository (abstract+Impl). 실사용 4메서드만 노출.
- `lib/src/view_models/weight/weight_detail_state.dart` — WeightDetailState (불변, copyWith).
- `lib/src/view_models/weight/weight_detail_view_model.dart` — WeightDetailViewModel.
- `test/repositories/schedule_repository_test.dart`
- `test/repositories/daily_record_repository_test.dart`
- `test/view_models/weight/weight_detail_view_model_test.dart`

**수정 파일:**
- `lib/src/providers/repository_providers.dart` — scheduleRepositoryProvider, dailyRecordRepositoryProvider 추가.
- `lib/src/screens/weight/weight_detail_screen.dart` — 서비스 필드 5개 제거, VM 경유로 전환.
- `lib/src/screens/weight/weight_record_screen.dart` — WeightService/BreedService/PetLocalCache 직접 호출 → provider/repository 경유.
- `lib/src/widgets/add_daily_record_bottom_sheet.dart` — prefill 조회를 DailyRecordRepository 경유(ConsumerStatefulWidget 전환).
- `lib/src/view_models/pet/active_pet_view_model.dart` — `deletePet(String petId)` 추가.
- `lib/src/repositories/pet_repository.dart` — `removeLocalCache(String petId)` + `getLocalPets()` 추가(삭제 흐름용).
- `lib/src/screens/profile/pet_profile_detail_screen.dart` — _handleSave/_handleDelete/_loadExistingPet를 VM 경유로.
- `test/view_models/pet/active_pet_view_model_test.dart` — deletePet 케이스 추가.

---

## Task 1: ScheduleRepository 신설

**Files:**
- Create: `lib/src/repositories/schedule_repository.dart`
- Create: `test/repositories/schedule_repository_test.dart`
- Modify: `lib/src/providers/repository_providers.dart`

**Interfaces:**
- Consumes: `ScheduleService` (createSchedule/fetchSchedulesByMonth/deleteSchedule), `ScheduleRecord` 모델.
- Produces:
  - `abstract class ScheduleRepository { Future<List<ScheduleRecord>> fetchByMonth({required String petId, required int year, required int month}); Future<ScheduleRecord> create(ScheduleRecord schedule); Future<void> delete(String id, {required String petId}); }`
  - `class ScheduleRepositoryImpl implements ScheduleRepository { ScheduleRepositoryImpl({ScheduleService? service}); }`
  - `final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) => ScheduleRepositoryImpl());`

- [ ] **Step 1: Write the failing test**

Create `test/repositories/schedule_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:perch_care/src/models/schedule_record.dart';
import 'package:perch_care/src/repositories/schedule_repository.dart';
import 'package:perch_care/src/services/schedule/schedule_service.dart';

class MockScheduleService extends Mock implements ScheduleService {}

class _ScheduleFake extends Fake implements ScheduleRecord {}

ScheduleRecord _schedule({String id = 's1', String petId = 'p1'}) =>
    ScheduleRecord(
      id: id,
      petId: petId,
      startTime: DateTime(2026, 4, 18, 9),
      endTime: DateTime(2026, 4, 18, 10),
      title: 'vet',
    );

void main() {
  late MockScheduleService service;
  late ScheduleRepository repo;

  setUpAll(() => registerFallbackValue(_ScheduleFake()));
  setUp(() {
    service = MockScheduleService();
    repo = ScheduleRepositoryImpl(service: service);
  });

  test('fetchByMonth delegates to service', () async {
    when(() => service.fetchSchedulesByMonth(
        petId: any(named: 'petId'),
        year: any(named: 'year'),
        month: any(named: 'month'))).thenAnswer((_) async => [_schedule()]);

    final result = await repo.fetchByMonth(petId: 'p1', year: 2026, month: 4);

    expect(result, hasLength(1));
    verify(() => service.fetchSchedulesByMonth(
        petId: 'p1', year: 2026, month: 4)).called(1);
  });

  test('create delegates to service and returns saved record', () async {
    final saved = _schedule(id: 'srv-1');
    when(() => service.createSchedule(any())).thenAnswer((_) async => saved);

    final result = await repo.create(_schedule());

    expect(result.id, 'srv-1');
    verify(() => service.createSchedule(any())).called(1);
  });

  test('delete delegates to service', () async {
    when(() => service.deleteSchedule(any(), petId: any(named: 'petId')))
        .thenAnswer((_) async {});

    await repo.delete('s1', petId: 'p1');

    verify(() => service.deleteSchedule('s1', petId: 'p1')).called(1);
  });

  test('create propagates service error (no offline queue)', () async {
    when(() => service.createSchedule(any())).thenThrow(Exception('500'));
    await expectLater(repo.create(_schedule()), throwsA(isA<Exception>()));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/repositories/schedule_repository_test.dart`
Expected: FAIL — `schedule_repository.dart` 없음 (compile error).

- [ ] **Step 3: Write minimal implementation**

Create `lib/src/repositories/schedule_repository.dart`:

```dart
import '../models/schedule_record.dart';
import '../services/schedule/schedule_service.dart';

/// 일정 Repository — ViewModel이 `ScheduleService`를 직접 알지 못하도록 래핑한다.
///
/// 실사용 3메서드만 노출(fetchByMonth/create/delete). Schedule에는 오프라인 큐가
/// 없으므로 저장/삭제 실패는 그대로 호출자에게 전파한다.
abstract class ScheduleRepository {
  Future<List<ScheduleRecord>> fetchByMonth({
    required String petId,
    required int year,
    required int month,
  });
  Future<ScheduleRecord> create(ScheduleRecord schedule);
  Future<void> delete(String id, {required String petId});
}

class ScheduleRepositoryImpl implements ScheduleRepository {
  ScheduleRepositoryImpl({ScheduleService? service})
      : _service = service ?? ScheduleService.instance;

  final ScheduleService _service;

  @override
  Future<List<ScheduleRecord>> fetchByMonth({
    required String petId,
    required int year,
    required int month,
  }) =>
      _service.fetchSchedulesByMonth(petId: petId, year: year, month: month);

  @override
  Future<ScheduleRecord> create(ScheduleRecord schedule) =>
      _service.createSchedule(schedule);

  @override
  Future<void> delete(String id, {required String petId}) =>
      _service.deleteSchedule(id, petId: petId);
}
```

Add to `lib/src/providers/repository_providers.dart` — add import at top with the other repository imports:
```dart
import '../repositories/schedule_repository.dart';
```
and add provider after `waterRepositoryProvider`:
```dart
final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => ScheduleRepositoryImpl(),
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/repositories/schedule_repository_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/repositories/schedule_repository.dart test/repositories/schedule_repository_test.dart lib/src/providers/repository_providers.dart
git commit -m "$(cat <<'EOF'
|FEAT| ScheduleRepository 신설 — ScheduleService 래핑(fetchByMonth/create/delete)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA
EOF
)"
```

---

## Task 2: DailyRecordRepository 신설

**Files:**
- Create: `lib/src/repositories/daily_record_repository.dart`
- Create: `test/repositories/daily_record_repository_test.dart`
- Modify: `lib/src/providers/repository_providers.dart`

**Interfaces:**
- Consumes: `DailyRecordService` (getRecordByDate/getRecordsByMonth/saveDailyRecord/deleteDailyRecordByDate), `DailyRecord` 모델.
- Produces:
  - `abstract class DailyRecordRepository { Future<DailyRecord?> getByDate(String petId, DateTime date); Future<List<DailyRecord>> getByMonth(String petId, int year, int month); Future<DailyRecord> save(DailyRecord record); Future<void> deleteByDate(String petId, DateTime date); }`
  - `class DailyRecordRepositoryImpl implements DailyRecordRepository { DailyRecordRepositoryImpl({DailyRecordService? service}); }`
  - `final dailyRecordRepositoryProvider = Provider<DailyRecordRepository>((ref) => DailyRecordRepositoryImpl());`

- [ ] **Step 1: Write the failing test**

Create `test/repositories/daily_record_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:perch_care/src/models/daily_record.dart';
import 'package:perch_care/src/repositories/daily_record_repository.dart';
import 'package:perch_care/src/services/daily_record/daily_record_service.dart';

class MockDailyRecordService extends Mock implements DailyRecordService {}

class _DailyRecordFake extends Fake implements DailyRecord {}

DailyRecord _record({String petId = 'p1'}) => DailyRecord(
      petId: petId,
      recordedDate: DateTime(2026, 4, 18),
      mood: 'good',
    );

void main() {
  late MockDailyRecordService service;
  late DailyRecordRepository repo;

  setUpAll(() => registerFallbackValue(_DailyRecordFake()));
  setUp(() {
    service = MockDailyRecordService();
    repo = DailyRecordRepositoryImpl(service: service);
  });

  test('getByDate delegates to service', () async {
    when(() => service.getRecordByDate(any(), any()))
        .thenAnswer((_) async => _record());
    final result = await repo.getByDate('p1', DateTime(2026, 4, 18));
    expect(result, isNotNull);
    verify(() => service.getRecordByDate('p1', DateTime(2026, 4, 18))).called(1);
  });

  test('getByMonth delegates to service', () async {
    when(() => service.getRecordsByMonth(any(), any(), any()))
        .thenAnswer((_) async => [_record()]);
    final result = await repo.getByMonth('p1', 2026, 4);
    expect(result, hasLength(1));
    verify(() => service.getRecordsByMonth('p1', 2026, 4)).called(1);
  });

  test('save delegates to service and returns record', () async {
    when(() => service.saveDailyRecord(any()))
        .thenAnswer((_) async => _record());
    final result = await repo.save(_record());
    expect(result.petId, 'p1');
    verify(() => service.saveDailyRecord(any())).called(1);
  });

  test('deleteByDate delegates to service', () async {
    when(() => service.deleteDailyRecordByDate(any(), any()))
        .thenAnswer((_) async {});
    await repo.deleteByDate('p1', DateTime(2026, 4, 18));
    verify(() => service.deleteDailyRecordByDate('p1', DateTime(2026, 4, 18)))
        .called(1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/repositories/daily_record_repository_test.dart`
Expected: FAIL — `daily_record_repository.dart` 없음.

- [ ] **Step 3: Write minimal implementation**

Create `lib/src/repositories/daily_record_repository.dart`:

```dart
import '../models/daily_record.dart';
import '../services/daily_record/daily_record_service.dart';

/// 일일 건강기록 Repository — `DailyRecordService`를 래핑한다.
///
/// 실사용 4메서드만 노출. 오프라인 큐 미도입 — 저장/삭제 실패는 호출자에게 전파.
abstract class DailyRecordRepository {
  Future<DailyRecord?> getByDate(String petId, DateTime date);
  Future<List<DailyRecord>> getByMonth(String petId, int year, int month);
  Future<DailyRecord> save(DailyRecord record);
  Future<void> deleteByDate(String petId, DateTime date);
}

class DailyRecordRepositoryImpl implements DailyRecordRepository {
  DailyRecordRepositoryImpl({DailyRecordService? service})
      : _service = service ?? DailyRecordService.instance;

  final DailyRecordService _service;

  @override
  Future<DailyRecord?> getByDate(String petId, DateTime date) =>
      _service.getRecordByDate(petId, date);

  @override
  Future<List<DailyRecord>> getByMonth(String petId, int year, int month) =>
      _service.getRecordsByMonth(petId, year, month);

  @override
  Future<DailyRecord> save(DailyRecord record) =>
      _service.saveDailyRecord(record);

  @override
  Future<void> deleteByDate(String petId, DateTime date) =>
      _service.deleteDailyRecordByDate(petId, date);
}
```

Add to `lib/src/providers/repository_providers.dart`:
```dart
import '../repositories/daily_record_repository.dart';
```
```dart
final dailyRecordRepositoryProvider = Provider<DailyRecordRepository>(
  (ref) => DailyRecordRepositoryImpl(),
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/repositories/daily_record_repository_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/repositories/daily_record_repository.dart test/repositories/daily_record_repository_test.dart lib/src/providers/repository_providers.dart
git commit -m "$(cat <<'EOF'
|FEAT| DailyRecordRepository 신설 — DailyRecordService 래핑(getByDate/getByMonth/save/deleteByDate)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA
EOF
)"
```

---

## Task 3: WeightDetailState + WeightDetailViewModel 신설 (화면 전환 전, 단위 테스트 우선)

**Files:**
- Create: `lib/src/view_models/weight/weight_detail_state.dart`
- Create: `lib/src/view_models/weight/weight_detail_view_model.dart`
- Create: `test/view_models/weight/weight_detail_view_model_test.dart`

**Interfaces:**
- Consumes: `weightRepositoryProvider`(WeightRepository.fetchAll/fetchLocal), `scheduleRepositoryProvider`, `dailyRecordRepositoryProvider`, `petRepositoryProvider`(getMyPets/getActivePet/upsertLocalCache/getActivePet 폴백), `activePetViewModelProvider`(watch).
- Produces:
  - `class WeightDetailState { final List<Pet> petList; final String? activePetId; final String petName; final List<WeightRecord> weightRecords; final List<ScheduleRecord> scheduleRecords; final List<DailyRecord> dailyRecords; ... copyWith }`
  - `class WeightDetailViewModel extends AsyncNotifier<WeightDetailState>` — 메서드: `Future<void> loadForMonth(int year, int month)`(schedule+daily만), `Future<void> reloadWeight()`, `Future<void> createSchedule(ScheduleRecord)`, `Future<void> deleteSchedule(ScheduleRecord)`(낙관적), `Future<void> saveDailyRecord(DailyRecord)`, `Future<void> deleteDailyRecordByDate(DateTime)`(리로드형).
  - `final weightDetailViewModelProvider = AsyncNotifierProvider<WeightDetailViewModel, WeightDetailState>(WeightDetailViewModel.new);`

**설계 노트 (behavior 보존):**
- `build()`는 `ref.watch(activePetViewModelProvider)`로 활성 펫을 읽어 초기 3-데이터 로드(weight+schedule+daily). 활성 펫 변경 시 자동 재빌드 → 재로드 (HomeViewModel 선례와 동일). 이로써 기존 `_onActivePetChanged` 가드/postFrameCallback을 VM이 대체한다.
- `build()` 내부에서 펫 목록(petList)도 `petRepository.getMyPets()`로 로드해 상태에 담는다(셀렉터용).
- 활성 펫이 null이면 `petRepository.getActivePet()` → 실패 시 로컬 캐시 폴백을 Repository가 처리(getActivePet 자체가 서비스 폴백 포함). petList는 비었으면 빈 리스트.
- **월(state에 담지 않음)**: 선택 월은 View 소유(폼/UI 상태). `loadForMonth(year, month)`가 해당 월 schedule+daily를 조회해 state 갱신. weight는 월 무관(전체)이라 월 변경 시 재조회 안 함 — 기존 `_setFocusedDate`의 부분 리로드 규칙 보존.
- `deleteSchedule`: 낙관적(state에서 즉시 제거) → repo.delete 실패 시 loadForMonth로 롤백. **View가 현재 선택 월을 인자로 넘긴다**(VM은 월 미보유).
- `deleteDailyRecordByDate`: repo.deleteByDate 후 loadForMonth 재조회(성공/실패 모두). View가 월 인자 전달.
- `createSchedule`/`saveDailyRecord`: repo 호출 후 loadForMonth 재조회. 실패는 rethrow(View가 스낵바). View가 월 인자 전달.
- 로드 실패 개별 처리: schedule/daily/weight 각 로더는 내부 try/catch로 빈 결과 유지(기존과 동일 — 화면이 죽지 않음).

- [ ] **Step 1: Write WeightDetailState (new file, complete)**

Create `lib/src/view_models/weight/weight_detail_state.dart`:

```dart
import '../../models/pet.dart';
import '../../models/weight_record.dart';
import '../../models/schedule_record.dart';
import '../../models/daily_record.dart';

/// weight_detail 화면 aggregated 상태. UI 선택 상태(선택 월/주-월 토글/확장 여부)는
/// 의도적으로 제외 — View 소유(폼 상태 규칙).
class WeightDetailState {
  const WeightDetailState({
    this.petList = const [],
    this.activePetId,
    this.petName = '',
    this.weightRecords = const [],
    this.scheduleRecords = const [],
    this.dailyRecords = const [],
  });

  final List<Pet> petList;
  final String? activePetId;
  final String petName;
  final List<WeightRecord> weightRecords;
  final List<ScheduleRecord> scheduleRecords;
  final List<DailyRecord> dailyRecords;

  WeightDetailState copyWith({
    List<Pet>? petList,
    String? activePetId,
    String? petName,
    List<WeightRecord>? weightRecords,
    List<ScheduleRecord>? scheduleRecords,
    List<DailyRecord>? dailyRecords,
  }) {
    return WeightDetailState(
      petList: petList ?? this.petList,
      activePetId: activePetId ?? this.activePetId,
      petName: petName ?? this.petName,
      weightRecords: weightRecords ?? this.weightRecords,
      scheduleRecords: scheduleRecords ?? this.scheduleRecords,
      dailyRecords: dailyRecords ?? this.dailyRecords,
    );
  }
}
```

- [ ] **Step 2: Write the failing ViewModel test**

Create `test/view_models/weight/weight_detail_view_model_test.dart`. This test drives the VM through a mock repository set + a fake ActivePetViewModel (home test 패턴 참고). Read `test/view_models/home/home_view_model_test.dart` first to copy the `overrideWith(() => _FakeActivePetViewModel(pet))` + `SynchronousFuture` idiom exactly.

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:perch_care/src/models/pet.dart';
import 'package:perch_care/src/models/weight_record.dart';
import 'package:perch_care/src/models/schedule_record.dart';
import 'package:perch_care/src/models/daily_record.dart';
import 'package:perch_care/src/providers/pet_providers.dart';
import 'package:perch_care/src/providers/repository_providers.dart';
import 'package:perch_care/src/repositories/pet_repository.dart';
import 'package:perch_care/src/repositories/weight_repository.dart';
import 'package:perch_care/src/repositories/schedule_repository.dart';
import 'package:perch_care/src/repositories/daily_record_repository.dart';
import 'package:perch_care/src/view_models/pet/active_pet_view_model.dart';
import 'package:perch_care/src/view_models/weight/weight_detail_view_model.dart';

class MockWeightRepository extends Mock implements WeightRepository {}
class MockScheduleRepository extends Mock implements ScheduleRepository {}
class MockDailyRecordRepository extends Mock implements DailyRecordRepository {}
class MockPetRepository extends Mock implements PetRepository {}

class _ScheduleFake extends Fake implements ScheduleRecord {}
class _DailyRecordFake extends Fake implements DailyRecord {}

class _FakeActivePetVM extends ActivePetViewModel {
  _FakeActivePetVM(this._pet);
  final Pet? _pet;
  @override
  Future<Pet?> build() => SynchronousFuture(_pet);
}

Pet _pet(String id) => Pet(
      id: id,
      userId: 'u1',
      name: 'Bori-$id',
      species: 'bird',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

WeightRecord _weight() =>
    WeightRecord(petId: 'p1', date: DateTime(2026, 4, 18), weight: 72);
ScheduleRecord _schedule({String id = 's1'}) => ScheduleRecord(
    id: id, petId: 'p1', startTime: DateTime(2026, 4, 18, 9),
    endTime: DateTime(2026, 4, 18, 10), title: 'vet');
DailyRecord _daily() =>
    DailyRecord(petId: 'p1', recordedDate: DateTime(2026, 4, 18), mood: 'good');

ProviderContainer _container({
  required WeightRepository weight,
  required ScheduleRepository schedule,
  required DailyRecordRepository daily,
  required PetRepository pet,
  Pet? activePet,
}) {
  final container = ProviderContainer(overrides: [
    weightRepositoryProvider.overrideWithValue(weight),
    scheduleRepositoryProvider.overrideWithValue(schedule),
    dailyRecordRepositoryProvider.overrideWithValue(daily),
    petRepositoryProvider.overrideWithValue(pet),
    activePetViewModelProvider.overrideWith(() => _FakeActivePetVM(activePet)),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  late MockWeightRepository weight;
  late MockScheduleRepository schedule;
  late MockDailyRecordRepository daily;
  late MockPetRepository pet;

  setUpAll(() {
    registerFallbackValue(_ScheduleFake());
    registerFallbackValue(_DailyRecordFake());
  });

  setUp(() {
    weight = MockWeightRepository();
    schedule = MockScheduleRepository();
    daily = MockDailyRecordRepository();
    pet = MockPetRepository();
    when(() => pet.getMyPets(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => [_pet('p1')]);
    when(() => weight.fetchAll(petId: any(named: 'petId')))
        .thenAnswer((_) async => [_weight()]);
    when(() => schedule.fetchByMonth(
        petId: any(named: 'petId'),
        year: any(named: 'year'),
        month: any(named: 'month'))).thenAnswer((_) async => [_schedule()]);
    when(() => daily.getByMonth(any(), any(), any()))
        .thenAnswer((_) async => [_daily()]);
  });

  test('build loads pet list + weight + schedule + daily for active pet', () async {
    final container = _container(
        weight: weight, schedule: schedule, daily: daily, pet: pet,
        activePet: _pet('p1'));
    final state = await container.read(weightDetailViewModelProvider.future);

    expect(state.activePetId, 'p1');
    expect(state.petList, hasLength(1));
    expect(state.weightRecords, hasLength(1));
    expect(state.scheduleRecords, hasLength(1));
    expect(state.dailyRecords, hasLength(1));
  });

  test('build with no active pet yields empty activePetId', () async {
    final container = _container(
        weight: weight, schedule: schedule, daily: daily, pet: pet,
        activePet: null);
    final state = await container.read(weightDetailViewModelProvider.future);
    expect(state.activePetId, isNull);
  });

  test('deleteSchedule optimistically removes then persists', () async {
    when(() => schedule.delete(any(), petId: any(named: 'petId')))
        .thenAnswer((_) async {});
    final container = _container(
        weight: weight, schedule: schedule, daily: daily, pet: pet,
        activePet: _pet('p1'));
    await container.read(weightDetailViewModelProvider.future);
    final vm = container.read(weightDetailViewModelProvider.notifier);

    await vm.deleteSchedule(_schedule(id: 's1'), year: 2026, month: 4);

    verify(() => schedule.delete('s1', petId: 'p1')).called(1);
    expect(container.read(weightDetailViewModelProvider).value!.scheduleRecords
        .where((s) => s.id == 's1'), isEmpty);
  });

  test('deleteSchedule rolls back via reload on failure', () async {
    when(() => schedule.delete(any(), petId: any(named: 'petId')))
        .thenThrow(Exception('500'));
    final container = _container(
        weight: weight, schedule: schedule, daily: daily, pet: pet,
        activePet: _pet('p1'));
    await container.read(weightDetailViewModelProvider.future);
    final vm = container.read(weightDetailViewModelProvider.notifier);

    await expectLater(
        vm.deleteSchedule(_schedule(id: 's1'), year: 2026, month: 4),
        throwsA(isA<Exception>()));
    // reload restored the record
    expect(container.read(weightDetailViewModelProvider).value!.scheduleRecords,
        hasLength(1));
  });

  test('createSchedule reloads month schedules', () async {
    when(() => schedule.create(any())).thenAnswer((_) async => _schedule());
    final container = _container(
        weight: weight, schedule: schedule, daily: daily, pet: pet,
        activePet: _pet('p1'));
    await container.read(weightDetailViewModelProvider.future);
    final vm = container.read(weightDetailViewModelProvider.notifier);

    await vm.createSchedule(_schedule(), year: 2026, month: 4);
    verify(() => schedule.create(any())).called(1);
    // fetchByMonth called at build + after create = 2
    verify(() => schedule.fetchByMonth(
        petId: 'p1', year: 2026, month: 4)).called(2);
  });

  test('saveDailyRecord reloads month dailies', () async {
    when(() => daily.save(any())).thenAnswer((_) async => _daily());
    final container = _container(
        weight: weight, schedule: schedule, daily: daily, pet: pet,
        activePet: _pet('p1'));
    await container.read(weightDetailViewModelProvider.future);
    final vm = container.read(weightDetailViewModelProvider.notifier);

    await vm.saveDailyRecord(_daily(), year: 2026, month: 4);
    verify(() => daily.save(any())).called(1);
    verify(() => daily.getByMonth('p1', 2026, 4)).called(2);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/view_models/weight/weight_detail_view_model_test.dart`
Expected: FAIL — `weight_detail_view_model.dart` 없음.

- [ ] **Step 4: Write the ViewModel (new file)**

Create `lib/src/view_models/weight/weight_detail_view_model.dart`. Mirror the exact load/mutate semantics from the current screen (`weight_detail_screen.dart` lines 127-287, 1476-1513, 1724-1740, 2000-2019 — read them). Implement:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pet.dart';
import '../../models/schedule_record.dart';
import '../../models/daily_record.dart';
import '../../providers/pet_providers.dart';
import '../../providers/repository_providers.dart';
import 'weight_detail_state.dart';

/// weight_detail 화면용 aggregated ViewModel.
///
/// activePetViewModelProvider를 watch → 활성 펫 전환 시 자동 재빌드/재로드.
/// (기존 화면의 provider→로컬 단방향 동기화 가드를 이 watch가 대체한다.)
/// 선택 월은 View 소유이므로 월 스코프 메서드는 year/month를 인자로 받는다.
class WeightDetailViewModel extends AsyncNotifier<WeightDetailState> {
  @override
  Future<WeightDetailState> build() async {
    final activePet = ref.watch(activePetViewModelProvider).valueOrNull;
    final petRepo = ref.read(petRepositoryProvider);

    // 셀렉터용 펫 목록 (실패해도 화면은 뜬다)
    List<Pet> pets = const [];
    try {
      pets = await petRepo.getMyPets();
    } catch (_) {}

    // 활성 펫: watch 값 우선, 없으면 repository(서비스+로컬 폴백 내장)
    Pet? pet = activePet;
    if (pet == null) {
      try {
        pet = await petRepo.getActivePet();
      } catch (_) {}
    }

    if (pet == null) {
      return WeightDetailState(petList: pets);
    }

    final now = DateTime.now();
    final results = await Future.wait([
      _loadWeight(pet.id),
      _loadSchedules(pet.id, now.year, now.month),
      _loadDailies(pet.id, now.year, now.month),
    ]);

    return WeightDetailState(
      petList: pets,
      activePetId: pet.id,
      petName: pet.name,
      weightRecords: results[0] as List,
      scheduleRecords: results[1] as List,
      dailyRecords: results[2] as List,
    ).cast();
  }

  // 개별 로더 — 실패 시 빈 리스트 (화면이 죽지 않도록)
  Future<List> _loadWeight(String petId) async {
    final repo = ref.read(weightRepositoryProvider);
    try {
      return await repo.fetchAll(petId: petId);
    } catch (_) {
      try {
        return await repo.fetchLocal(petId: petId);
      } catch (_) {
        return const [];
      }
    }
  }

  Future<List> _loadSchedules(String petId, int year, int month) async {
    try {
      return await ref
          .read(scheduleRepositoryProvider)
          .fetchByMonth(petId: petId, year: year, month: month);
    } catch (_) {
      return const [];
    }
  }

  Future<List> _loadDailies(String petId, int year, int month) async {
    try {
      return await ref
          .read(dailyRecordRepositoryProvider)
          .getByMonth(petId, year, month);
    } catch (_) {
      return const [];
    }
  }

  String? get _petId => state.valueOrNull?.activePetId;

  /// 월 변경 시 schedule+daily만 재조회(weight는 전체이므로 불변).
  Future<void> loadForMonth(int year, int month) async {
    final petId = _petId;
    final current = state.valueOrNull;
    if (petId == null || current == null) return;
    final results = await Future.wait([
      _loadSchedules(petId, year, month),
      _loadDailies(petId, year, month),
    ]);
    state = AsyncData(current.copyWith(
      scheduleRecords: results[0].cast<ScheduleRecord>(),
      dailyRecords: results[1].cast<DailyRecord>(),
    ));
  }

  Future<void> reloadWeight() async {
    final petId = _petId;
    final current = state.valueOrNull;
    if (petId == null || current == null) return;
    final records = await _loadWeight(petId);
    state = AsyncData(current.copyWith(weightRecords: records.cast()));
  }

  Future<void> createSchedule(
      ScheduleRecord schedule, {required int year, required int month}) async {
    await ref.read(scheduleRepositoryProvider).create(schedule);
    await loadForMonth(year, month);
  }

  /// 낙관적 삭제 — state에서 즉시 제거 후 서버 삭제. 실패 시 loadForMonth 롤백 후 rethrow.
  Future<void> deleteSchedule(
      ScheduleRecord schedule, {required int year, required int month}) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      scheduleRecords:
          current.scheduleRecords.where((r) => r.id != schedule.id).toList(),
    ));
    try {
      await ref
          .read(scheduleRepositoryProvider)
          .delete(schedule.id, petId: schedule.petId);
    } catch (e) {
      await loadForMonth(year, month);
      rethrow;
    }
  }

  Future<void> saveDailyRecord(
      DailyRecord record, {required int year, required int month}) async {
    await ref.read(dailyRecordRepositoryProvider).save(record);
    await loadForMonth(year, month);
  }

  /// 리로드형 삭제 — 성공/실패 모두 loadForMonth. 실패 시 rethrow(View 스낵바).
  Future<void> deleteDailyRecordByDate(
      DateTime date, {required int year, required int month}) async {
    final petId = _petId;
    if (petId == null) return;
    try {
      await ref.read(dailyRecordRepositoryProvider).deleteByDate(petId, date);
      await loadForMonth(year, month);
    } catch (e) {
      await loadForMonth(year, month);
      rethrow;
    }
  }
}

final weightDetailViewModelProvider =
    AsyncNotifierProvider<WeightDetailViewModel, WeightDetailState>(
        WeightDetailViewModel.new);
```

> Note: `.cast()` on the `WeightDetailState(...)` build return is a placeholder — remove it; construct the state with the correctly-typed `results[i] as List<T>`. Cast each `Future.wait` element explicitly: `weightRecords: (results[0] as List).cast<WeightRecord>()`, etc. Ensure imports for `WeightRecord` are added. Fix all `List` return types to concrete types during implementation and run `flutter analyze` to catch mismatches.

- [ ] **Step 5: Run test + analyze to verify PASS**

Run: `flutter test test/view_models/weight/weight_detail_view_model_test.dart && flutter analyze lib/src/view_models/weight/`
Expected: tests PASS, analyze clean. Fix all type-cast issues surfaced by analyze.

- [ ] **Step 6: Commit**

```bash
git add lib/src/view_models/weight/weight_detail_state.dart lib/src/view_models/weight/weight_detail_view_model.dart test/view_models/weight/weight_detail_view_model_test.dart
git commit -m "$(cat <<'EOF'
|FEAT| WeightDetailViewModel + WeightDetailState 신설 — weight/schedule/daily aggregate, 활성펫 watch

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA
EOF
)"
```

---

## Task 4: weight_detail_screen을 ViewModel 경유로 전환

**Files:**
- Modify: `lib/src/screens/weight/weight_detail_screen.dart`

**Interfaces:**
- Consumes: `weightDetailViewModelProvider` (watch state + read notifier), `WeightDetailState`.
- Produces: 없음(화면).

**전환 규칙 (behavior-preserving — 이 파일은 반드시 현재 코드를 Read 후 적용):**

1. **서비스 필드 5개 제거** (L35-39): `_weightService/_scheduleService/_dailyRecordService/_petCache/_petService`. import도 제거(weight_service/schedule_service/daily_record_service/pet_local_cache_service/pet_service). `weight_detail_view_model.dart` + `weight_detail_state.dart` import 추가.
2. **로컬 데이터 상태 제거**: `_weightRecords/_scheduleRecords/_dailyRecords/_petName/_activePetId/_isLoading/_petList` (L56-62)를 제거하고, build()에서 `final vmAsync = ref.watch(weightDetailViewModelProvider); final vm = vmAsync.valueOrNull;`로 읽는다. 화면 곳곳의 `_weightRecords` → `vm?.weightRecords ?? []`, `_scheduleRecords` → `vm?.scheduleRecords ?? []`, `_dailyRecords` → `vm?.dailyRecords ?? []`, `_petName` → `vm?.petName ?? ''`, `_activePetId` → `vm?.activePetId`, `_petList` → `vm?.petList ?? []`로 치환. `_isLoading` → `vmAsync.isLoading`.
3. **UI 상태는 유지**: `_isWeeklyView`, `_focusedDate`(+ `_selectedYear/_selectedMonth/_selectedDay` getter), `_isRecordsExpanded`, 차트 캐시 3종(`_cachedMonthlyAverages/_cachedWeeklyData/_cachedWeeklyStart`), `_scrollController`, 코치마크 GlobalKey 6개는 View 소유로 남긴다.
4. **`initState`의 `_loadActivePet()` 제거** — VM.build가 초기 로드를 담당. `_loadActivePet/_onActivePetChanged/_loadWeightData/_loadScheduleData/_loadDailyRecordData` 메서드 삭제. build()의 provider→로컬 동기화 가드(L363-370)도 삭제(VM watch가 대체).
5. **차트 캐시 무효화**: 캐시는 `vm?.weightRecords`가 바뀔 때만 재계산해야 한다. `_weightRecords`를 참조하던 캐시 계산부를 `final weightRecords = vm?.weightRecords ?? const <WeightRecord>[];`를 지역 변수로 잡아 계산에 쓰고, 캐시 키를 `identical`이 아닌 값 기준으로 유지하기 어렵다면 **캐시 필드를 제거하고 매 build 계산**으로 단순화한다(월별/주간 평균 계산은 O(n), 기록 수가 작아 무해). 캐시 제거를 기본 방침으로 한다.
6. **월 변경**: `_setFocusedDate`의 `isMonthChanged` 분기에서 `_loadScheduleData(); _loadDailyRecordData();` → `ref.read(weightDetailViewModelProvider.notifier).loadForMonth(newYear, newMonth);`로 교체. `_focusedDate` setState는 유지(UI 상태). year/month는 `normalizedDate.year/month`.
7. **일정 생성** (`_openScheduleBottomSheetFor`, L1476-1488): `_scheduleService.createSchedule(result); await _loadScheduleData();` → `await ref.read(weightDetailViewModelProvider.notifier).createSchedule(result, year: _selectedYear, month: _selectedMonth);` catch에서 `schedule_saveError` 스낵바 유지.
8. **일일기록 저장** (`_openDailyRecordBottomSheetFor`, L1498-1512): 동일 패턴 — `notifier.saveDailyRecord(result, year:, month:)`, 성공 시 `dailyRecord_saved`, 실패 시 `dailyRecord_saveError`.
9. **일일기록 삭제** (Dismissible onDismissed, L1724-1740): `notifier.deleteDailyRecordByDate(record.recordedDate, year: _selectedYear, month: _selectedMonth)` — try에서 성공 스낵바, catch에서 에러 스낵바(리로드는 VM 내부에서 수행).
10. **일정 삭제** (`_deleteSchedule`, L2000-2019): 낙관적 로컬 제거 setState 삭제 → `try { await notifier.deleteSchedule(schedule, year: _selectedYear, month: _selectedMonth); 성공 스낵바 } catch { 에러 스낵바 }` (낙관적 제거+롤백은 VM이 수행).
11. **코치마크**: `_maybeShowCoachMarks`는 유지하되, 초기 로드 완료 후 1회 노출 조건이 필요. build에서 `vmAsync.hasValue && vm?.activePetId != null && !_coachMarkShown`일 때 `addPostFrameCallback`으로 1회 호출하고 `_coachMarkShown=true` 가드. (기존엔 `_loadActivePet` 성공 후 호출됐음.)
12. **빈/로딩 상태**: `vmAsync.isLoading && !vmAsync.hasValue` → 로딩 스피너. `vm?.activePetId == null`(값 있고 펫 없음) → `weightDetail_noPet`.

- [ ] **Step 1: Read the current screen fully** (2,561줄 — offset로 나눠 전체). 특히 build()의 위젯 트리에서 위 상태 변수들이 참조되는 모든 지점을 목록화.

- [ ] **Step 2: Apply the transition edits** per rules 1-12 above.

- [ ] **Step 3: Run analyze**

Run: `flutter analyze lib/src/screens/weight/weight_detail_screen.dart`
Expected: No issues. 모든 잔존 `_weightRecords`/`_activePetId` 등 참조가 vm 경유로 바뀌었는지 확인.

- [ ] **Step 4: Run full test suite**

Run: `flutter test`
Expected: 전체 PASS (기존 + 신규).

- [ ] **Step 5: Commit**

```bash
git add lib/src/screens/weight/weight_detail_screen.dart
git commit -m "$(cat <<'EOF'
|REFACTOR| weight_detail_screen MVVM 전환 — 서비스 5종 직접 호출 제거, WeightDetailViewModel 경유

- 활성펫 동기화를 VM watch로 일원화(기존 provider→로컬 가드 삭제)
- 월 변경 부분 리로드·일정 낙관적 삭제·일일기록 리로드 삭제 시맨틱 보존
- 차트 캐시 필드 제거(매 build 계산, O(n))

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA
EOF
)"
```

---

## Task 5: add_daily_record_bottom_sheet를 DailyRecordRepository 경유로

**Files:**
- Modify: `lib/src/widgets/add_daily_record_bottom_sheet.dart`

**전환 규칙:**
- 현재 `final _dailyRecordService = DailyRecordService.instance;`(L33) + `_dailyRecordService.getRecordByDate(...)`(L61) 직접 호출. 이 위젯은 일반 StatefulWidget.
- **ConsumerStatefulWidget으로 전환** — `flutter_riverpod` import 추가, `State`→`ConsumerState`, prefill 로드에서 `ref.read(dailyRecordRepositoryProvider).getByDate(widget.petId!, _selectedDate)` 사용. `repository_providers.dart` import 추가.
- `showAddDailyRecordBottomSheet` 진입 함수(L661-687)는 시그니처 불변. 내부에서 위젯이 ProviderScope 컨텍스트 하에 뜨는지 확인(앱 전체가 ProviderScope로 감싸져 있으므로 `showModalBottomSheet`로 뜬 위젯도 ref 접근 가능).
- 저장 경로(onSave 콜백)는 그대로 — 저장은 caller(weight_detail_screen)가 VM 경유로 이미 처리.
- 나머지 폼 로직/setState/에러 무시(prefill 실패)는 보존.

- [ ] **Step 1: Read current widget** (687줄). prefill 호출 3지점(initState L47, 캘린더 날짜 변경 L522/L553/L614에서 `_loadExistingRecord`) 확인.

- [ ] **Step 2: Convert to ConsumerStatefulWidget + repository read.** `_loadExistingRecord`가 `ref`를 쓰도록. (ConsumerState는 `ref` 필드 제공.)

- [ ] **Step 3: Run analyze**

Run: `flutter analyze lib/src/widgets/add_daily_record_bottom_sheet.dart`
Expected: No issues.

- [ ] **Step 4: Run full test suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/widgets/add_daily_record_bottom_sheet.dart
git commit -m "$(cat <<'EOF'
|REFACTOR| add_daily_record_bottom_sheet — prefill 조회를 DailyRecordRepository 경유(Consumer 전환)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA
EOF
)"
```

---

## Task 6: weight_record_screen 잔여 직접 호출 정리

**Files:**
- Modify: `lib/src/screens/weight/weight_record_screen.dart`

**전환 규칙:**
- L33 `_weightService`, L34 `_petCache` 필드 제거.
- L159 `_weightService.fetchLocalRecords(petId: _activePetId)` → `ref.read(weightRepositoryProvider).fetchLocal(petId: _activePetId!)` (petId null 가드 유지 — 이미 상위에서 처리).
- L77 `BreedService.instance.fetchBreedById(...)` → `ref.read(breedServiceProvider).fetchBreedById(...)` (breedServiceProvider는 service_providers.dart에 이미 존재).
- L87/L99 `_petCache.getActivePet()` 폴백 → `ref.read(petRepositoryProvider).getActivePet()` (PetRepository.getActivePet가 서비스+로컬 폴백 포함). 단 활성펫은 이미 `activePetProvider` watch로 받으므로, 폴백 자체가 필요한지 확인 후 최소 변경. **로컬 캐시 직접 접근만 제거**가 목표 — getActivePet로 대체하되 동작 동일 확인.
- import 정리: weight_service/breed_service/pet_local_cache_service 제거, repository_providers/service_providers 추가.
- CoachMarkService(L119)는 유지(cross-cutting 예외).

- [ ] **Step 1: Read current screen** (985줄). L60-100 활성펫 로드, L150-165 기록 로드, L70-85 breed 로드 확인.

- [ ] **Step 2: Apply edits.** 저장 경로(L314 weightAddViewModelProvider)는 이미 전환 완료 — 건드리지 않는다.

- [ ] **Step 3: Run analyze**

Run: `flutter analyze lib/src/screens/weight/weight_record_screen.dart`
Expected: No issues.

- [ ] **Step 4: Run full test suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/screens/weight/weight_record_screen.dart
git commit -m "$(cat <<'EOF'
|REFACTOR| weight_record_screen — 조회 경로 Repository/provider 경유(WeightService/BreedService/PetLocalCache 직접 호출 제거)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA
EOF
)"
```

---

## Task 7: PetRepository 로컬 캐시 삭제 지원 + ActivePetViewModel.deletePet

**Files:**
- Modify: `lib/src/repositories/pet_repository.dart`
- Modify: `lib/src/view_models/pet/active_pet_view_model.dart`
- Modify: `test/view_models/pet/active_pet_view_model_test.dart`

**Interfaces:**
- Produces:
  - `PetRepository.removeLocalCache(String petId)` — 로컬 캐시에서 펫 제거.
  - `PetRepository.getLocalPets()` — 로컬 캐시 펫 목록(삭제 후 남은 펫 판단용).
  - `ActivePetViewModel.deletePet(String petId)` — 서버 삭제 + 로컬 캐시 제거 + petList invalidate + 남은 펫으로 switch/clear.

- [ ] **Step 1: Read `pet_repository.dart` + `active_pet_view_model.dart` + `pet_local_cache_service.dart`** (인터페이스 확인: `removePet(String)`, `getPets()` → `List<PetProfileCache>`).

- [ ] **Step 2: Write the failing test** — add to `test/view_models/pet/active_pet_view_model_test.dart` (read it first to match style):

```dart
  test('deletePet: 서버+캐시 삭제 후 남은 펫으로 전환', () async {
    when(() => repo.deletePet(any())).thenAnswer((_) async {});
    when(() => repo.removeLocalCache(any())).thenAnswer((_) async {});
    when(() => repo.getMyPets(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => [_pet('p2')]);
    when(() => repo.setActivePet(any())).thenAnswer((_) async {});
    when(() => repo.getActivePet(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => _pet('p2'));
    // ... container 구성(기존 테스트 패턴) 후:
    final vm = container.read(activePetViewModelProvider.notifier);
    await vm.deletePet('p1');
    verify(() => repo.deletePet('p1')).called(1);
    verify(() => repo.removeLocalCache('p1')).called(1);
    verify(() => repo.setActivePet('p2')).called(1);
  });
```
(정확한 `_pet` 헬퍼/`repo`/`container` 심볼은 기존 파일에 맞춰 사용. 남은 펫이 없을 때 clear()가 호출되는 케이스도 1개 추가.)

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/view_models/pet/active_pet_view_model_test.dart`
Expected: FAIL — `removeLocalCache`/`deletePet` 미정의.

- [ ] **Step 4: Implement.**

`pet_repository.dart` — abstract에 추가:
```dart
  /// 로컬 캐시에서 펫 제거.
  Future<void> removeLocalCache(String petId);

  /// 로컬 캐시 펫 목록.
  Future<List<Pet>> getLocalPets();
```
Impl에 추가 (PetProfileCache → Pet 매핑은 최소 필드만; 삭제 후 "남은 펫이 있는가/첫 펫 id" 판단에만 쓰이므로 id/name/species 채우면 충분):
```dart
  @override
  Future<void> removeLocalCache(String petId) => _cache.removePet(petId);

  @override
  Future<List<Pet>> getLocalPets() async {
    final cached = await _cache.getPets();
    return cached
        .map((c) => Pet(
              id: c.id,
              userId: '',
              name: c.name,
              species: c.species ?? '',
              gender: c.gender,
              birthDate: c.birthDate,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ))
        .toList();
  }
```
> 확인: `Pet` 생성자 필수 필드(id/userId/name/species/createdAt/updatedAt)를 실제 모델(`models/pet.dart`)에서 Read해 정확히 맞춘다.

`active_pet_view_model.dart` — `deletePet` 추가 (기존 switchPet/clear/refresh 옆에):
```dart
  /// 펫 삭제 — 서버+로컬 캐시 제거 후, 남은 펫이 있으면 첫 펫으로 전환, 없으면 clear.
  Future<void> deletePet(String petId) async {
    final repo = ref.read(petRepositoryProvider);
    await repo.deletePet(petId);
    await repo.removeLocalCache(petId);
    // 서버 기준 남은 펫 (실패 시 로컬 캐시 폴백)
    List<Pet> remaining;
    try {
      remaining = await repo.getMyPets(forceRefresh: true);
    } catch (_) {
      remaining = await repo.getLocalPets();
    }
    ref.invalidate(petListViewModelProvider);
    if (remaining.isNotEmpty) {
      await switchPet(remaining.first.id);
    } else {
      clear();
    }
  }
```
> `switchPet`가 이미 `petRepository.setActivePet` + state 갱신을 수행하는지 확인(active_pet_view_model.dart Read). `petListViewModelProvider` import 필요.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/view_models/pet/active_pet_view_model_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/repositories/pet_repository.dart lib/src/view_models/pet/active_pet_view_model.dart test/view_models/pet/active_pet_view_model_test.dart
git commit -m "$(cat <<'EOF'
|FEAT| ActivePetViewModel.deletePet + PetRepository 로컬 캐시 삭제 지원 — pet_profile_detail 삭제 흐름 흡수 준비

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA
EOF
)"
```

---

## Task 8: pet_profile_detail_screen을 VM 경유로 전환

**Files:**
- Modify: `lib/src/screens/profile/pet_profile_detail_screen.dart`

**전환 규칙 (동작 개선 포함 — 아래 명시):**
1. **서비스 필드 제거** (L35-36): `_petCache`, `_petService`. import 제거(pet_service/pet_local_cache_service). `LocalImageStorageService`는 이미지 로드/저장에 계속 쓰이므로 유지(cross-cutting storage) — 단 가능하면 유지, 아니면 그대로.
2. **`_handleSave` (L786-870)**: create/update 분기 + `LocalImageStorageService.saveImage` + `_petCache.upsertPet`를 **모두 `ref.read(petAddViewModelProvider.notifier).save(input: PetFormInput(...), newImage: _selectedImage, existingPet: <기존 Pet or null>)` 한 번으로 대체**.
   - `PetFormInput` 필드(name/species/breedId/breedDisplayName/gender/growthStage/weight/birthDate/adoptionDate)를 폼 상태에서 조립. 상세 화면은 breedId/growthStage를 입력받지 않으므로 해당 필드는 null/기존값. **species 빈 값 처리**: 기존엔 `l10n.pet_defaultName`을 저장(버그성). PetAddViewModel 경유 시 VM 내부 로직을 따름 → **동작 개선(플래그)**.
   - `existingPet`: 편집 모드면 activePet(또는 로드한 Pet), 신규면 null. VM.save가 create/update를 알아서 분기.
   - 저장 성공 후 VM이 petList/activePet invalidate + 초기 체중 기록 + analytics를 수행하므로, 화면의 수동 캐시 upsert/네비게이션 후 재로딩 의존을 제거. 네비게이션(canPop ? pop() : goNamed(home), L855-859)은 유지.
3. **`_handleDelete` (L745-783)**: `_petService.deletePet` + `AnalyticsService.logPetDeleted` + `_petCache.removePet` + `_petCache.getPets` + switchPet 전체를 **`await ref.read(activePetViewModelProvider.notifier).deletePet(_existingPetId!)`로 대체**. 삭제 후 `pop(true)` 유지. **`_existingPetId` null 가드 추가**(신규 모드에서 삭제 버튼 → early return, 기존 null 단언 크래시 버그 수정 — 플래그).
   - analytics(logPetDeleted)는 VM으로 옮기지 않고 View에서 호출 유지(cross-cutting 예외) 또는 삭제 성공 후 호출. **결정: View에서 삭제 성공 후 `AnalyticsService.instance.logPetDeleted()` 호출 유지**(기존 위치 보존).
4. **`_loadExistingPet` (L76-142)**: `activePetProvider`에서 펫 읽는 부분은 유지. `_petCache.upsertPet` 부수효과(L93)와 `_petCache.getActivePet` 폴백(L122)은 제거 가능 — 활성펫은 provider가 SSOT. 이미지 로드(`LocalImageStorageService.getImage`)는 유지. 최소 변경으로 캐시 직접 호출만 제거.
5. **저장 중 상태**: `_isLoading`은 View 로컬로 유지(VM.save는 AsyncNotifier state를 자체 관리하지만, 이 화면은 petAddViewModelProvider state를 watch하지 않고 명령형 호출만 하므로 로컬 `_isLoading` 토글 유지).

**동작 변경 플래그 (최종 보고 대상):**
- (a) species 빈 값 저장이 `l10n.pet_defaultName`(로케일 문자열) → PetAddViewModel 기본값('bird'/'default')으로 변경 — 개선.
- (b) 신규 등록 시 초기 체중 기록 + logPetRegistered analytics가 추가됨(기존 상세 화면 create 경로엔 없었음) — 개선.
- (c) `_existingPetId!` null 단언 크래시(신규 모드 삭제 버튼) → early-return으로 수정 — 버그 수정.
- (d) 저장 성공 시 petList/activePet invalidate 추가 → 홈/프로필 stale 데이터 해소. profile_screen의 복귀 후 수동 `_loadPets()`는 Stage 3에서 정리(여기선 그대로 둬도 무해).

- [ ] **Step 1: Read** `pet_profile_detail_screen.dart`(871줄) 전체 + `pet_add_screen.dart`의 `_handleSave`(L188-245, PetFormInput 조립 참고) + `pet_add_view_model.dart`(save/loadExistingPet 시그니처).

- [ ] **Step 2: Apply edits** per rules 1-5.

- [ ] **Step 3: Run analyze**

Run: `flutter analyze lib/src/screens/profile/pet_profile_detail_screen.dart`
Expected: No issues.

- [ ] **Step 4: Run full test suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/screens/profile/pet_profile_detail_screen.dart
git commit -m "$(cat <<'EOF'
|REFACTOR| pet_profile_detail_screen MVVM 전환 — PetAddViewModel.save + ActivePetViewModel.deletePet로 우회 해소

- 저장/삭제/캐시 동기화를 View에서 제거, 표준 VM 경로로 일원화
- species 기본값 정정·초기 체중 기록 추가·삭제 null 크래시 수정(동작 개선)
- 저장 성공 시 petList/activePet invalidate로 stale 데이터 해소

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA
EOF
)"
```

---

## Self-Review (스펙 대비)

- **Repository 신설** (스펙 Stage 2 #1): Task 1(Schedule) + Task 2(DailyRecord) ✅
- **WeightRepository 보강** (#2): 이미 완비 → weight_detail(Task 4)·weight_record(Task 6) 조회 경로 전환으로 실사용화 ✅
- **weight_detail_screen 전환** (#3): Task 3(VM 신설) + Task 4(화면 전환). 위젯 추출은 차트 캐시 제거로 대체(파일 분할은 리스크 대비 이득이 낮아 보류 — 최종 보고에 명시) ⚠️
- **weight_record_screen** (#4): Task 6 ✅
- **pet 구멍** (#5): Task 7(deletePet 인프라) + Task 8(화면 전환) ✅. pet_profile_screen L35 AuthService.getProfile은 **Stage 4로 보류**(스펙 명시). profile_screen의 PetService 직접 호출 7곳은 **Stage 3에서 정리**(스펙: profile pet/locale 부분).
- **add_daily_record_bottom_sheet** (#6): Task 5 ✅

**Placeholder scan:** Task 3 Step 4의 `.cast()` 플레이스홀더는 명시적으로 "구현 시 제거하고 concrete 타입으로" 지시함. 그 외 없음.

**Type consistency:** ScheduleRepository.create/delete, DailyRecordRepository.save/deleteByDate, ActivePetViewModel.deletePet, PetRepository.removeLocalCache/getLocalPets 시그니처는 Task 간 일관.

**보류/후속 (최종 보고):** 위젯 파일 분할(스펙 허용 사항) 보류, profile_screen 7곳·pet_profile_screen AuthService는 Stage 3/4.
