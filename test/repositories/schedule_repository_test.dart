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
      color: ScheduleRecord.colorPalette[0],
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
