# MVVM 아키텍처 도입 — Riverpod 기반 표준 5-layer 구조 점진 전환 (Phase 1-3)

**날짜**: 2026-04-18
**배경**: 기존 Riverpod 기반 "부분 MVVM" 구조(Phase 0-7 마이그레이션 결과)를 **명시적이고 일관된 표준 MVVM 5-layer 아키텍처**로 승격. 핵심 도메인(pet / home / weight / food / water)부터 우선 전환하여 테스트성과 레이어 분리의 실익을 확보.
**선행 커밋**: `8a646eb |DOCS| 앱 시작 성능 최적화 개발 로그 추가`
**검증**: `flutter analyze` clean (0 issues) · `flutter test` **178/178 pass** (기존 169 + ViewModel 단위 9).

---

## 변경 요약

### 새 파일 (18개, 1772 lines)

| 카테고리 | 경로 | 라인 | 역할 |
|----------|------|-----|------|
| **Base** | `lib/src/view_models/base/async_view_model.dart` | 32 | AsyncNotifier 공통 base · `runLoad(loader)` 헬퍼 |
| **Pet** | `lib/src/view_models/pet/pet_list_view_model.dart` | 23 | 펫 목록 |
| **Pet** | `lib/src/view_models/pet/active_pet_view_model.dart` | 39 | 활성 펫 SSOT |
| **Pet** | `lib/src/view_models/pet/pet_add_view_model.dart` | 232 | 등록/수정 save flow (초기 체중 + 이미지 + 로컬캐시) |
| **Home** | `lib/src/view_models/home/home_state.dart` | 76 | 홈 화면 불변 state (12 필드 + copyWith) |
| **Home** | `lib/src/view_models/home/home_view_model.dart` | 153 | activePet watch → aggregated 데이터 로드 |
| **Weight** | `lib/src/view_models/weight/weight_add_view_model.dart` | 39 | 체중 저장 |
| **Food** | `lib/src/view_models/food/food_record_view_model.dart` | 45 | 음식 entries 로드/저장 |
| **Water** | `lib/src/view_models/water/water_record_view_model.dart` | 44 | 수분 총량 로드/저장 |
| **Repo** | `lib/src/repositories/pet_repository.dart` | 149 | PetService + PetLocalCacheService 래핑 |
| **Repo** | `lib/src/repositories/home_repository.dart` | 194 | Pet+BHI+Summary+Insight+Sync aggregated facade |
| **Repo** | `lib/src/repositories/weight_repository.dart` | 163 | 로컬 우선 + unawaited 백엔드 + 실패 시 enqueue |
| **Repo** | `lib/src/repositories/food_repository.dart` | 133 | SharedPreferences + 서버 upsert + SaveOutcome 반환 |
| **Repo** | `lib/src/repositories/water_repository.dart` | 119 | 동일 패턴 |
| **Repo** | `lib/src/repositories/save_outcome.dart` | 5 | enum `SaveOutcome { online, offline }` |
| **DI** | `lib/src/providers/repository_providers.dart` | 27 | `petRepositoryProvider` 외 5개 Repository DI |
| **Test** | `test/view_models/pet/pet_list_view_model_test.dart` | 84 | Repository mock + 3 시나리오 |
| **Test** | `test/view_models/home/home_view_model_test.dart` | 163 | empty/full/offline/period 4 시나리오 |
| **Test** | `test/view_models/weight/weight_add_view_model_test.dart` | 79 | save 성공/실패 2 시나리오 |

### 수정된 screen 파일 (7개)

| 파일 | 수정 요지 |
|------|----------|
| `lib/src/providers/pet_providers.dart` | **`ActivePetNotifier` / `PetListNotifier` 클래스 제거**. 새 ViewModel re-export + legacy alias (`activePetProvider = activePetViewModelProvider`) 로 호환성 유지 → 18개 caller 무변경 |
| `lib/src/screens/pet/pet_profile_screen.dart` | `_petCache` / `_petService` 직접 참조 제거 → `ref.watch(petListViewModelProvider)` · `ref.watch(activePetViewModelProvider)` |
| `lib/src/screens/pet/pet_add_screen.dart` | 170 lines의 save flow(create/update + 체중 + 이미지 + 캐시) → `ref.read(petAddViewModelProvider.notifier).save(input)` 호출 한 줄로 축약 |
| `lib/src/screens/home/home_screen.dart` | `_refreshForPet` / `_loadPets` / `_syncOfflineData` / `_checkLocalDataForBadges` / `_loadBhi` / `_loadBhiForSelectedPeriod` / `_loadHealthSummaryAndInsights` 총 **~180 lines 비즈니스 로직 제거**. State 필드는 ViewModel state의 mirror로만 유지 (1500 lines UI 위젯 코드 무변경) |
| `lib/src/screens/weight/weight_add_screen.dart` | `_syncToBackend` 제거, `ref.read(weightAddViewModelProvider.notifier).saveRecord(record)` |
| `lib/src/screens/weight/weight_record_screen.dart` | `_saveWeight` 내부의 SyncService enqueue/markSynced/drain 로직 제거 |
| `lib/src/screens/food/food_record_screen.dart` | `_loadEntries` + `_saveEntries`를 ViewModel 호출로 교체. `SaveOutcome.offline` 시 스낵바 분기 |
| `lib/src/screens/water/water_record_screen.dart` | 동일 패턴 |

---

## 설계 결정

### Option A 채택 — Riverpod + 명시적 ViewModel
- **선택 이유**: 122 dart 파일 + Phase 0-7 Riverpod 마이그레이션 완료된 현 상태에서 `ChangeNotifier + provider` 로의 재마이그레이션은 리스크 대비 실익 작음. Notifier 클래스를 **ViewModel로 명시화**하고 Repository 레이어를 추가하는 점진적 승격이 표준 MVVM의 이점을 그대로 주면서 재작성 비용은 최소.
- 대안으로 검토: `stacked` 패키지 (MVVM 전용 프레임워크) — 외부 의존 증가 + Riverpod 제거 부담으로 배제.

### Scope B 채택 — 핵심 도메인 우선
- pet / home / weight / food / water 5개 도메인 (자주 수정되고 실익 큰 구간).
- 나머지 auth / health_check / ai_encyclopedia / bhi / premium / profile 등은 향후 별도 Phase로 점진 전환.

### Layer B 채택 — 표준 MVVM 5-layer
```
View (Screen, ConsumerWidget)
  ↓ ref.watch(xxxViewModelProvider)
ViewModel (AsyncNotifier<State>)
  ↓ ref.read(xxxRepositoryProvider)
Repository (abstract + impl)
  ├── Service (기존 26개 유지)
  └── LocalDataSource (SharedPreferences / SQLite)
        ↓
     Model (POJO)
```
- **UseCase 레이어 생략** (Clean Architecture 변형) — 파일 수 2-3배 증가 대비 실익 작음. 대신 ViewModel이 Repository만 의존하여 단위 테스트 용이성 확보.

---

## 주요 패턴

### 1. Legacy provider alias (18 caller 호환)
```dart
// lib/src/providers/pet_providers.dart (Phase 1 리팩터 후)
export '../view_models/pet/active_pet_view_model.dart';
export '../view_models/pet/pet_list_view_model.dart';

/// @deprecated — `activePetViewModelProvider` 사용 권장.
final activePetProvider = activePetViewModelProvider;
final petListProvider = petListViewModelProvider;
```
18개 caller(`screens/**/*.dart` + `providers/auth_actions.dart` 등)가 `activePetProvider` / `petListProvider` 이름을 유지한 채 내부만 새 ViewModel로 교체됨 → 무변경.

### 2. SyncService 책임의 Repository 이관
Phase 3의 가장 큰 가치. 기존에는 4개 screen (weight_add, weight_record, food_record, water_record)이 각자 `SyncService.enqueue()` / `markMutationSynced()` / `drainAfterSuccess()`를 호출.

변경 후: `WeightRepository.saveRecord()` 안에서 모든 sync 로직 캡슐화.
```dart
@override
Future<WeightRecord> saveRecord(WeightRecord record) async {
  final local = await _service.saveLocalWeightRecord(record);
  unawaited(_syncToBackend(local));  // fire-and-forget
  return local;
}

Future<void> _syncToBackend(WeightRecord local) async {
  try {
    await _service.saveWeightRecord(local);
    await _sync.markMutationSynced(...);
    await _sync.drainAfterSuccess();
  } catch (e) {
    await _sync.enqueue(SyncItem(...));  // 실패 시 자동 큐 적재
  }
}
```

### 3. SaveOutcome 패턴 (Food/Water)
Food/Water는 저장 결과(online/offline)를 UI 스낵바로 구분 표시하므로 `SaveOutcome` enum 반환.
```dart
final outcome = await ref.read(foodRecordViewModelProvider.notifier).saveEntries(...);
if (outcome == SaveOutcome.offline) {
  AppSnackBar.info(context, message: l10n.snackbar_savedOffline);
}
```

### 4. HomeState + state mirroring (1500 lines UI 무변경)
`home_screen.dart`는 1560 lines의 거대한 위젯. 기존 위젯 메서드들이 `_activePet`, `_bhiResult` 등 인스턴스 필드를 직접 참조. 리팩터 전략:
```dart
@override
Widget build(BuildContext context) {
  final state = ref.watch(homeViewModelProvider).valueOrNull ?? const HomeState();
  // state → 필드 mirror (기존 위젯 메서드들이 계속 참조 가능)
  _activePet = state.activePet;
  _bhiResult = state.bhi;
  // ...
}
```
엄격한 MVVM은 아니지만, 위젯 코드 전면 재작성 없이 비즈니스 로직만 ViewModel로 이관.

---

## 테스트

### Mock Repository 패턴
```dart
class MockPetRepository extends Mock implements PetRepository {}

test('build()는 Repository.getMyPets()를 호출한다', () async {
  when(() => repo.getMyPets(forceRefresh: false))
      .thenAnswer((_) async => [_pet('p1')]);
  final container = ProviderContainer(overrides: [
    petRepositoryProvider.overrideWithValue(repo),
  ]);
  final pets = await container.read(petListViewModelProvider.future);
  expect(pets.first.id, 'p1');
});
```

### HomeViewModel의 dependent provider 주의점
HomeVM은 `ref.watch(activePetViewModelProvider)` 하므로, 테스트에서 `SynchronousFuture`로 즉시 resolve하는 Fake 필요:
```dart
class _FakeActivePetViewModel extends ActivePetViewModel {
  _FakeActivePetViewModel(this._value);
  final Pet? _value;
  @override
  Future<Pet?> build() => SynchronousFuture<Pet?>(_value);
}
```
일반 `async build`로는 첫 HomeVM build가 loading 상태에서 끝나 테스트가 timeout.

### Firebase Analytics try/catch
ViewModel 내 `AnalyticsService.instance.logXxx()` 호출은 Firebase 미초기화 테스트 환경에서 예외. 호출을 `try/catch (_)`로 감싸 테스트 용이성 확보.

---

## 남은 작업 (이번 PR 범위 외)

- auth / health_check / ai_encyclopedia / bhi / premium / profile 도메인 점진 전환
- HomeRepository를 더 작은 단위 Repository (BhiRepository, HealthSummaryRepository)로 분할 (현재는 facade)
- Food/Water ViewModel에 대한 단위 테스트 추가 (Phase 3에선 Weight만)
- FoodRecordScreen의 `_loadFoodNameSuggestions` 등 일부 SharedPreferences 직접 접근을 FoodRepository로 이관

---

## 검증
- `flutter analyze` → **No issues found!**
- `flutter test` → **178 tests passed** (기존 169 + Pet 3 + Home 4 + Weight 2)
- 수동 리뷰: 각 Phase 종료 시점에 실사용처/회귀 포인트 재점검 (Phase 1에서 죽은 메서드 4개 제거, Phase 2에서 state mirror 패턴 주석 명시, Phase 3에서 Analytics try/catch 추가)
