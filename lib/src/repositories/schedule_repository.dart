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
  Future<ScheduleRecord> create(ScheduleRecord schedule) async =>
      _service.createSchedule(schedule);

  @override
  Future<void> delete(String id, {required String petId}) =>
      _service.deleteSchedule(id, petId: petId);
}
