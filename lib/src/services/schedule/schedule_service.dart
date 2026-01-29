import '../../models/schedule_record.dart';
import '../api/api_client.dart';

/// 일정 관리 서비스
/// FastAPI schedules 엔드포인트와 연동
class ScheduleService {
  ScheduleService();

  final _api = ApiClient.instance;

  /// 일정 생성
  Future<ScheduleRecord> createSchedule(ScheduleRecord schedule) async {
    final response = await _api.post(
      '/pets/${schedule.petId}/schedules/',
      body: schedule.toInsertJson(),
    );
    return ScheduleRecord.fromJson(response);
  }

  /// 특정 펫의 모든 일정 조회
  Future<List<ScheduleRecord>> fetchSchedules({
    required String petId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final params = <String, String>{};
    if (startDate != null) params['start'] = startDate.toIso8601String();
    if (endDate != null) params['end'] = endDate.toIso8601String();

    final response = await _api.get(
      '/pets/$petId/schedules/',
      queryParams: params.isNotEmpty ? params : null,
    );

    return (response as List)
        .map((json) => ScheduleRecord.fromJson(json))
        .toList();
  }

  /// 특정 월의 일정 조회
  Future<List<ScheduleRecord>> fetchSchedulesByMonth({
    required String petId,
    required int year,
    required int month,
  }) async {
    final response = await _api.get(
      '/pets/$petId/schedules/by-month',
      queryParams: {
        'year': year.toString(),
        'month': month.toString(),
      },
    );

    return (response as List)
        .map((json) => ScheduleRecord.fromJson(json))
        .toList();
  }

  /// 오늘 일정 조회
  Future<List<ScheduleRecord>> fetchTodaySchedules({required String petId}) async {
    final response = await _api.get('/pets/$petId/schedules/today');
    return (response as List)
        .map((json) => ScheduleRecord.fromJson(json))
        .toList();
  }

  /// 특정 날짜의 일정 조회
  Future<List<ScheduleRecord>> fetchSchedulesByDate({
    required String petId,
    required DateTime date,
  }) async {
    final dateStr = date.toIso8601String().split('T').first;
    final response = await _api.get('/pets/$petId/schedules/by-date/$dateStr');

    return (response as List)
        .map((json) => ScheduleRecord.fromJson(json))
        .toList();
  }

  /// 일정 수정
  Future<ScheduleRecord> updateSchedule(ScheduleRecord schedule) async {
    final response = await _api.put(
      '/pets/${schedule.petId}/schedules/${schedule.id}',
      body: schedule.toInsertJson(),
    );
    return ScheduleRecord.fromJson(response);
  }

  /// 일정 삭제
  Future<void> deleteSchedule(String id, {required String petId}) async {
    await _api.delete('/pets/$petId/schedules/$id');
  }

  /// 여러 일정 삭제 (펫 삭제 시 사용)
  Future<void> deleteSchedulesByPetId(String petId) async {
    await _api.delete('/pets/$petId/schedules/');
  }
}
