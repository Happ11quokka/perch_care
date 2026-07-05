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
    id: id,
    petId: 'p1',
    startTime: DateTime(2026, 4, 18, 9),
    endTime: DateTime(2026, 4, 18, 10),
    title: 'vet',
    color: ScheduleRecord.colorPalette[0]);
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
    // fetchByMonth called at build (real "now" month) + after create (2026-04) = 2.
    // Deviation from brief: verify uses `any(named:...)` for year/month instead of
    // hardcoded (2026, 4) because build() loads the initial month using the real
    // DateTime.now() (mirrors legacy screen's `_focusedDate = DateTime.now()`), so
    // asserting a fixed year/month on the build-time call would make this test
    // date-dependent (it would only pass when run in April 2026).
    verify(() => schedule.fetchByMonth(
        petId: 'p1',
        year: any(named: 'year'),
        month: any(named: 'month'))).called(2);
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
    // Same date-independence deviation as above (build's initial month vs. real "now").
    verify(() => daily.getByMonth('p1', any(), any())).called(2);
  });
}
