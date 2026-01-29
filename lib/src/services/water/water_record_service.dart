import '../../models/water_intake_record.dart';
import '../api/api_client.dart';

/// 수분 기록 CRUD 서비스
class WaterRecordService {
  WaterRecordService();

  final _api = ApiClient.instance;

  /// 전체 수분 기록 조회
  Future<List<WaterIntakeRecord>> getAll(String petId) async {
    final response = await _api.get('/pets/$petId/water-records/');
    return (response as List).map((json) => WaterIntakeRecord.fromJson(json)).toList();
  }

  /// 특정 날짜 수분 기록 조회
  Future<WaterIntakeRecord?> getByDate(String petId, DateTime date) async {
    final dateStr = date.toIso8601String().split('T').first;
    try {
      final response = await _api.get('/pets/$petId/water-records/by-date/$dateStr');
      return response != null ? WaterIntakeRecord.fromJson(response) : null;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// 날짜 범위 수분 기록 조회
  Future<List<WaterIntakeRecord>> getByRange(String petId, DateTime start, DateTime end) async {
    final startStr = start.toIso8601String().split('T').first;
    final endStr = end.toIso8601String().split('T').first;
    final response = await _api.get('/pets/$petId/water-records/range?start=$startStr&end=$endStr');
    return (response as List).map((json) => WaterIntakeRecord.fromJson(json)).toList();
  }

  /// 수분 기록 생성/업데이트 (upsert)
  Future<WaterIntakeRecord> upsert({
    required String petId,
    required DateTime recordedDate,
    required double totalMl,
    required double targetMl,
    int count = 1,
  }) async {
    final body = <String, dynamic>{
      'recorded_date': recordedDate.toIso8601String().split('T').first,
      'total_ml': totalMl,
      'target_ml': targetMl,
      'count': count,
    };
    final response = await _api.post('/pets/$petId/water-records/', body: body);
    return WaterIntakeRecord.fromJson(response);
  }

  /// 특정 날짜 수분 기록 삭제
  Future<void> deleteByDate(String petId, DateTime date) async {
    final dateStr = date.toIso8601String().split('T').first;
    await _api.delete('/pets/$petId/water-records/by-date/$dateStr');
  }
}
