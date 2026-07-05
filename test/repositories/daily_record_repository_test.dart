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
