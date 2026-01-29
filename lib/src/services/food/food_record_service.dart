import '../../models/food_record.dart';
import '../api/api_client.dart';

/// 음식 기록 CRUD 서비스
class FoodRecordService {
  FoodRecordService();

  final _api = ApiClient.instance;

  /// 전체 음식 기록 조회
  Future<List<FoodRecord>> getAll(String petId) async {
    final response = await _api.get('/pets/$petId/food-records/');
    return (response as List).map((json) => FoodRecord.fromJson(json)).toList();
  }

  /// 특정 날짜 음식 기록 조회
  Future<FoodRecord?> getByDate(String petId, DateTime date) async {
    final dateStr = date.toIso8601String().split('T').first;
    try {
      final response = await _api.get('/pets/$petId/food-records/by-date/$dateStr');
      return response != null ? FoodRecord.fromJson(response) : null;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// 날짜 범위 음식 기록 조회
  Future<List<FoodRecord>> getByRange(String petId, DateTime start, DateTime end) async {
    final startStr = start.toIso8601String().split('T').first;
    final endStr = end.toIso8601String().split('T').first;
    final response = await _api.get('/pets/$petId/food-records/range?start=$startStr&end=$endStr');
    return (response as List).map((json) => FoodRecord.fromJson(json)).toList();
  }

  /// 음식 기록 생성/업데이트 (upsert)
  Future<FoodRecord> upsert({
    required String petId,
    required DateTime recordedDate,
    required double totalGrams,
    required double targetGrams,
    int count = 1,
    String? entriesJson,
  }) async {
    final body = <String, dynamic>{
      'recorded_date': recordedDate.toIso8601String().split('T').first,
      'total_grams': totalGrams,
      'target_grams': targetGrams,
      'count': count,
      if (entriesJson != null) 'entries_json': entriesJson,
    };
    final response = await _api.post('/pets/$petId/food-records/', body: body);
    return FoodRecord.fromJson(response);
  }

  /// 특정 날짜 음식 기록 삭제
  Future<void> deleteByDate(String petId, DateTime date) async {
    final dateStr = date.toIso8601String().split('T').first;
    await _api.delete('/pets/$petId/food-records/by-date/$dateStr');
  }
}
