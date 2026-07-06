import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:perch_care/src/models/pet.dart';
import 'package:perch_care/src/providers/pet_providers.dart';
import 'package:perch_care/src/providers/repository_providers.dart';
import 'package:perch_care/src/repositories/health_check_repository.dart';
import 'package:perch_care/src/services/storage/health_check_storage_service.dart';
import 'package:perch_care/src/view_models/health_check/health_check_history_view_model.dart';
import 'package:perch_care/src/view_models/pet/active_pet_view_model.dart';

class MockHealthCheckRepository extends Mock implements HealthCheckRepository {}

class _HealthCheckRecordFake extends Fake implements HealthCheckRecord {}

class _FakeActivePetVM extends ActivePetViewModel {
  _FakeActivePetVM(this._pet);
  Pet? _pet;
  @override
  Future<Pet?> build() => SynchronousFuture(_pet);

  /// 테스트 전용 — 펫 전환 시뮬레이션. state를 직접 갱신해
  /// activePetViewModelProvider를 watch하는 HealthCheckHistoryViewModel의
  /// build()를 (같은 인스턴스 위에서) 재실행시킨다.
  void simulateSwitchTo(Pet? pet) {
    _pet = pet;
    state = AsyncData(pet);
  }
}

Pet _pet(String id) => Pet(
      id: id,
      userId: 'u1',
      name: 'Bori-$id',
      species: 'bird',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

HealthCheckRecord _record(String id, {String petId = 'p1'}) => HealthCheckRecord(
      id: id,
      petId: petId,
      mode: 'full_body',
      result: const {},
      status: 'normal',
      checkedAt: DateTime(2026, 4, 18),
    );

ProviderContainer _container({
  required HealthCheckRepository repo,
  Pet? activePet,
}) {
  final container = ProviderContainer(overrides: [
    healthCheckRepositoryProvider.overrideWithValue(repo),
    activePetViewModelProvider.overrideWith(() => _FakeActivePetVM(activePet)),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  late MockHealthCheckRepository repo;

  setUpAll(() {
    registerFallbackValue(_HealthCheckRecordFake());
  });

  setUp(() {
    repo = MockHealthCheckRepository();
  });

  test('build with active pet loads history via repo.loadHistory', () async {
    when(() => repo.loadHistory('p1'))
        .thenAnswer((_) async => [_record('r1'), _record('r2')]);
    final container = _container(repo: repo, activePet: _pet('p1'));

    final state = await container.read(healthCheckHistoryViewModelProvider.future);

    expect(state, hasLength(2));
    verify(() => repo.loadHistory('p1')).called(1);
  });

  test('build with no active pet returns empty list without calling repo', () async {
    final container = _container(repo: repo, activePet: null);

    final state = await container.read(healthCheckHistoryViewModelProvider.future);

    expect(state, isEmpty);
    verifyNever(() => repo.loadHistory(any()));
  });

  test('delete calls repo.delete and optimistically removes record from state',
      () async {
    when(() => repo.loadHistory('p1'))
        .thenAnswer((_) async => [_record('r1'), _record('r2')]);
    when(() => repo.delete(any())).thenAnswer((_) async {});
    final container = _container(repo: repo, activePet: _pet('p1'));
    await container.read(healthCheckHistoryViewModelProvider.future);
    final vm = container.read(healthCheckHistoryViewModelProvider.notifier);

    await vm.delete(_record('r1'));

    verify(() => repo.delete(any())).called(1);
    final state = container.read(healthCheckHistoryViewModelProvider).value!;
    expect(state.map((r) => r.id), ['r2']);
  });

  test('build reloads history when active pet switches', () async {
    when(() => repo.loadHistory('p1'))
        .thenAnswer((_) async => [_record('r1', petId: 'p1')]);
    when(() => repo.loadHistory('p2'))
        .thenAnswer((_) async => [_record('r2', petId: 'p2'), _record('r3', petId: 'p2')]);
    final container = _container(repo: repo, activePet: _pet('p1'));
    await container.read(healthCheckHistoryViewModelProvider.future);

    final activePetNotifier =
        container.read(activePetViewModelProvider.notifier) as _FakeActivePetVM;
    activePetNotifier.simulateSwitchTo(_pet('p2'));

    final state = await container.read(healthCheckHistoryViewModelProvider.future);

    expect(state, hasLength(2));
    verify(() => repo.loadHistory('p2')).called(1);
  });
}
