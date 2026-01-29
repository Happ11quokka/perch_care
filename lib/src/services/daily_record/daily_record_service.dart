import '../../models/daily_record.dart';
import '../api/api_client.dart';

/// 일일 건강 기록 서비스 (캘린더용)
class DailyRecordService {
  DailyRecordService();

  final _api = ApiClient.instance;

  /// 특정 펫의 모든 일일 기록 조회
  Future<List<DailyRecord>> getDailyRecords(String petId) async {
    final response = await _api.get('/pets/$petId/daily-records/');
    return (response as List)
        .map((json) => DailyRecord.fromJson(json))
        .toList();
  }

  /// 특정 날짜의 일일 기록 조회
  Future<DailyRecord?> getRecordByDate(String petId, DateTime date) async {
    final dateStr = _formatDate(date);
    final response = await _api.get('/pets/$petId/daily-records/by-date/$dateStr');
    return response != null ? DailyRecord.fromJson(response) : null;
  }

  /// 특정 월의 일일 기록 조회 (캘린더용)
  Future<List<DailyRecord>> getRecordsByMonth(
    String petId,
    int year,
    int month,
  ) async {
    final response = await _api.get(
      '/pets/$petId/daily-records/by-month',
      queryParams: {
        'year': year.toString(),
        'month': month.toString(),
      },
    );

    return (response as List)
        .map((json) => DailyRecord.fromJson(json))
        .toList();
  }

  /// 일일 기록 저장 또는 수정 (Upsert)
  Future<DailyRecord> saveDailyRecord(DailyRecord record) async {
    final response = await _api.post(
      '/pets/${record.petId}/daily-records/',
      body: {
        'recorded_date': _formatDate(record.recordedDate),
        if (record.notes != null) 'notes': record.notes,
        if (record.mood != null) 'mood': record.mood,
        if (record.activityLevel != null) 'activity_level': record.activityLevel,
      },
    );

    return DailyRecord.fromJson(response);
  }

  /// 일일 기록 삭제
  Future<void> deleteDailyRecord(String recordId) async {
    // pet_id is needed for the URL; pass a placeholder since API identifies by record_id
    await _api.delete('/pets/_/daily-records/$recordId');
  }

  /// 특정 날짜의 일일 기록 삭제
  Future<void> deleteDailyRecordByDate(String petId, DateTime date) async {
    final dateStr = _formatDate(date);
    await _api.delete('/pets/$petId/daily-records/by-date/$dateStr');
  }

  /// 특정 기간의 일일 기록 조회
  Future<List<DailyRecord>> getRecordsByDateRange(
    String petId,
    DateTime start,
    DateTime end,
  ) async {
    final response = await _api.get(
      '/pets/$petId/daily-records/range',
      queryParams: {
        'start': _formatDate(start),
        'end': _formatDate(end),
      },
    );

    return (response as List)
        .map((json) => DailyRecord.fromJson(json))
        .toList();
  }

  /// 날짜 포맷 (YYYY-MM-DD)
  String _formatDate(DateTime date) {
    return date.toIso8601String().split('T').first;
  }
}
