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
