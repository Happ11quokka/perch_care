import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:perch_care/src/models/bhi_result.dart';
import 'package:perch_care/src/models/pet.dart';
import 'package:perch_care/src/providers/repository_providers.dart';
import 'package:perch_care/src/repositories/home_repository.dart';
import 'package:perch_care/src/view_models/home/home_view_model.dart';
import 'package:perch_care/src/view_models/pet/active_pet_view_model.dart';

class MockHomeRepository extends Mock implements HomeRepository {}

/// build()가 즉시(synchronous) 값을 반환하여, HomeVM의 ref.watch가 loading 상태를
/// 거치지 않고 바로 pet을 받도록 하는 fake.
class _FakeActivePetViewModel extends ActivePetViewModel {
  _FakeActivePetViewModel(this._value);
  final Pet? _value;
  @override
  Future<Pet?> build() => SynchronousFuture<Pet?>(_value);
}

/// 첫 build()는 실패하고, 이후 build()부터는 pet을 반환하는 fake —
/// 활성 펫 provider 자체가 실패한 상황에서의 HomeVM 복구 검증용.
class _FlakyActivePetViewModel extends ActivePetViewModel {
  _FlakyActivePetViewModel(this._value);
  final Pet _value;
  int buildCount = 0;
  @override
  Future<Pet?> build() {
    buildCount++;
    if (buildCount == 1) return Future<Pet?>.error(Exception('pet offline'));
    return SynchronousFuture<Pet?>(_value);
  }
}

Pet _pet(String id) => Pet(
      id: id,
      userId: 'u',
      name: 'Bori',
      species: 'bird',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

BhiResult _bhi({
  int level = 3,
  bool weight = true,
  bool food = true,
  bool water = false,
}) {
  return BhiResult(
    bhiScore: 72,
    weightScore: 80,
    foodScore: 70,
    waterScore: 60,
    wciLevel: level,
    targetDate: DateTime(2026, 4, 18),
    hasWeightData: weight,
    hasFoodData: food,
    hasWaterData: water,
  );
}

ProviderContainer _container({
  required HomeRepository repo,
  Pet? activePet,
}) {
  final container = ProviderContainer(overrides: [
    homeRepositoryProvider.overrideWithValue(repo),
    activePetViewModelProvider
        .overrideWith(() => _FakeActivePetViewModel(activePet)),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  late MockHomeRepository repo;

  setUp(() {
    repo = MockHomeRepository();
  });

  group('HomeViewModel', () {
    test('activePet이 null이면 기본 HomeState(empty)를 반환한다', () async {
      final container = _container(repo: repo, activePet: null);

      final state = await container.read(homeViewModelProvider.future);

      expect(state.activePet, isNull);
      expect(state.bhi, isNull);
      expect(state.wciLevel, 0);
      expect(state.isBhiOffline, isFalse);
      verifyNever(() => repo.loadPetWithBhi(any(), any()));
    });

    test('activePet이 있으면 Repository에서 펫+BHI+파생 데이터를 모두 로드한다', () async {
      final pet = _pet('p1');
      final bhi = _bhi(level: 4);
      when(() => repo.loadPetWithBhi(any(), any()))
          .thenAnswer((_) async => (pet: pet, bhi: bhi));
      when(() => repo.loadHealthDerivedData(any()))
          .thenAnswer((_) async => const HomeDerivedData());
      when(() => repo.lastBhiFetchTime).thenReturn(DateTime(2026, 4, 18, 10));

      final container = _container(repo: repo, activePet: pet);

      final state = await container.read(homeViewModelProvider.future);

      expect(state.activePet?.id, 'p1');
      expect(state.bhi, same(bhi));
      expect(state.wciLevel, 4);
      expect(state.hasWeight, isTrue);
      expect(state.hasFood, isTrue);
      expect(state.hasWater, isFalse);
      expect(state.isBhiOffline, isFalse);
      expect(state.lastBhiFetchTime, isNotNull);
      verify(() => repo.loadPetWithBhi('p1', any())).called(1);
      verify(() => repo.loadHealthDerivedData('p1')).called(1);
    });

    test('BHI가 null이면 isBhiOffline=true + 로컬 데이터로 배지 복원', () async {
      final pet = _pet('p1');
      when(() => repo.loadPetWithBhi(any(), any()))
          .thenAnswer((_) async => (pet: pet, bhi: null));
      when(() => repo.checkLocalDataAvailability(any(), any()))
          .thenAnswer((_) async => const LocalDataAvailability(
                hasWeight: true,
                hasFood: false,
                hasWater: true,
              ));
      when(() => repo.loadHealthDerivedData(any()))
          .thenAnswer((_) async => const HomeDerivedData());
      when(() => repo.lastBhiFetchTime).thenReturn(null);

      final container = _container(repo: repo, activePet: pet);

      final state = await container.read(homeViewModelProvider.future);

      expect(state.isBhiOffline, isTrue);
      expect(state.wciLevel, 0);
      expect(state.hasWeight, isTrue);
      expect(state.hasFood, isFalse);
      expect(state.hasWater, isTrue);
    });

    test('loadBhiForDate()는 새 BHI로 state를 갱신한다', () async {
      final pet = _pet('p1');
      final initialBhi = _bhi(level: 2);
      final periodBhi = _bhi(level: 5);
      when(() => repo.loadPetWithBhi(any(), any()))
          .thenAnswer((_) async => (pet: pet, bhi: initialBhi));
      when(() => repo.loadHealthDerivedData(any()))
          .thenAnswer((_) async => const HomeDerivedData());
      when(() => repo.lastBhiFetchTime).thenReturn(DateTime.now());
      when(() => repo.loadBhiForDate(any(), any()))
          .thenAnswer((_) async => periodBhi);

      final container = _container(repo: repo, activePet: pet);
      await container.read(homeViewModelProvider.future);

      await container
          .read(homeViewModelProvider.notifier)
          .loadBhiForDate(DateTime(2026, 3, 1));

      final state = container.read(homeViewModelProvider).value!;
      expect(state.bhi?.wciLevel, 5);
      expect(state.wciLevel, 5);
      expect(state.isBhiLoading, isFalse);
      expect(state.isBhiOffline, isFalse);
      verify(() => repo.loadBhiForDate('p1', any())).called(1);
    });

    // F06 회귀: 첫 로드 실패(AsyncError) 후 당겨서 새로고침으로 복구돼야 한다.
    test('pullToRefresh()는 초기 로드 실패(AsyncError) 후 전체 초기 로드로 복구한다',
        () async {
      final pet = _pet('p1');
      final bhi = _bhi(level: 3);
      when(() => repo.loadPetWithBhi(any(), any()))
          .thenThrow(Exception('offline'));
      when(() => repo.loadHealthDerivedData(any()))
          .thenAnswer((_) async => const HomeDerivedData());
      when(() => repo.lastBhiFetchTime).thenReturn(null);

      final container = _container(repo: repo, activePet: pet);
      await expectLater(
          container.read(homeViewModelProvider.future), throwsException);
      expect(container.read(homeViewModelProvider).hasError, isTrue);

      // 서버 복구
      when(() => repo.loadPetWithBhi(any(), any()))
          .thenAnswer((_) async => (pet: pet, bhi: bhi));
      when(() => repo.loadBhiForDate(any(), any(), forceRefresh: true))
          .thenAnswer((_) async => bhi);

      await container
          .read(homeViewModelProvider.notifier)
          .pullToRefresh(DateTime(2026, 3, 1));

      final async = container.read(homeViewModelProvider);
      expect(async.hasError, isFalse);
      expect(async.value?.activePet?.id, 'p1');
      expect(async.value?.bhi, same(bhi));
      expect(async.value?.wciLevel, 3);
      // 복구 경로는 초기 로더(Pet+BHI+파생) 재실행 — 화면이 선택한 기간을 그대로 사용.
      verify(() => repo.loadPetWithBhi('p1', DateTime(2026, 3, 1))).called(1);
      // 첫 빌드는 loadPetWithBhi에서 동기 throw → 파생 로더 미도달. 복구 시 1회.
      verify(() => repo.loadHealthDerivedData('p1')).called(1);
      verifyNever(() => repo.loadBhiForDate(any(), any(),
          forceRefresh: any(named: 'forceRefresh')));
    });

    test('retry() 재실패 시 AsyncError를 유지하고 예외를 밖으로 던지지 않는다', () async {
      final pet = _pet('p1');
      when(() => repo.loadPetWithBhi(any(), any()))
          .thenThrow(Exception('still offline'));
      when(() => repo.loadHealthDerivedData(any()))
          .thenAnswer((_) async => const HomeDerivedData());
      when(() => repo.lastBhiFetchTime).thenReturn(null);

      final container = _container(repo: repo, activePet: pet);
      await expectLater(
          container.read(homeViewModelProvider.future), throwsException);

      // RefreshIndicator.onRefresh 등 호출자에게 예외가 전파되면 안 된다.
      await container.read(homeViewModelProvider.notifier).retry();

      final async = container.read(homeViewModelProvider);
      expect(async.hasError, isTrue);
      expect(async.isLoading, isFalse);
      expect(async.hasValue, isFalse);
      verify(() => repo.loadPetWithBhi('p1', any())).called(2);
    });

    test('활성 펫 provider가 실패했을 때 retry()는 펫 로드까지 다시 수행해 복구한다',
        () async {
      final pet = _pet('p1');
      final bhi = _bhi(level: 2);
      final flaky = _FlakyActivePetViewModel(pet);
      when(() => repo.loadPetWithBhi(any(), any()))
          .thenAnswer((_) async => (pet: pet, bhi: bhi));
      when(() => repo.loadHealthDerivedData(any()))
          .thenAnswer((_) async => const HomeDerivedData());
      when(() => repo.lastBhiFetchTime).thenReturn(null);

      final container = ProviderContainer(overrides: [
        homeRepositoryProvider.overrideWithValue(repo),
        activePetViewModelProvider.overrideWith(() => flaky),
      ]);
      addTearDown(container.dispose);

      // 활성 펫 provider 에러 → HomeVM은 펫 없음(empty)으로 보인다.
      final sub = container.listen(homeViewModelProvider, (_, __) {});
      addTearDown(sub.close);
      await expectLater(
          container.read(activePetViewModelProvider.future), throwsException);
      await container.read(homeViewModelProvider.future);
      expect(container.read(homeViewModelProvider).value?.activePet, isNull);
      verifyNever(() => repo.loadPetWithBhi(any(), any()));

      await container
          .read(homeViewModelProvider.notifier)
          .pullToRefresh(DateTime(2026, 3, 1));
      await container.pump();

      final state = container.read(homeViewModelProvider).value;
      expect(flaky.buildCount, 2);
      expect(state?.activePet?.id, 'p1');
      expect(state?.bhi, same(bhi));
      verify(() => repo.loadPetWithBhi('p1', any())).called(1);
    });
  });
}
