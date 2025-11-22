import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/weight_record.dart';

/// 체중 데이터 관리 서비스 (Supabase 연동)
class WeightService {
  WeightService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// 특정 펫의 모든 체중 기록 조회
  Future<List<WeightRecord>> getWeightRecords(String petId) async {
    final response = await _client
        .from('weight_records')
        .select()
        .eq('pet_id', petId)
        .order('recorded_date', ascending: false);

    return (response as List)
        .map((json) => WeightRecord.fromJson(json))
        .toList();
  }

  /// 특정 날짜의 체중 기록 조회
  Future<WeightRecord?> getRecordByDate(String petId, DateTime date) async {
    final dateStr = _formatDate(date);

    final response = await _client
        .from('weight_records')
        .select()
        .eq('pet_id', petId)
        .eq('recorded_date', dateStr)
        .maybeSingle();

    return response != null ? WeightRecord.fromJson(response) : null;
  }

  /// 체중 기록 저장 또는 수정 (Upsert)
  Future<WeightRecord> saveWeightRecord(WeightRecord record) async {
    final response = await _client
        .from('weight_records')
        .upsert(
          record.toInsertJson(),
          onConflict: 'pet_id,recorded_date',
        )
        .select()
        .single();

    return WeightRecord.fromJson(response);
  }

  /// 체중 기록 삭제
  Future<void> deleteWeightRecord(String recordId) async {
    await _client.from('weight_records').delete().eq('id', recordId);
  }

  /// 특정 날짜의 체중 기록 삭제
  Future<void> deleteWeightRecordByDate(String petId, DateTime date) async {
    final dateStr = _formatDate(date);
    await _client
        .from('weight_records')
        .delete()
        .eq('pet_id', petId)
        .eq('recorded_date', dateStr);
  }

  /// 특정 기간의 체중 기록 조회
  Future<List<WeightRecord>> getRecordsByDateRange(
    String petId,
    DateTime start,
    DateTime end,
  ) async {
    final response = await _client
        .from('weight_records')
        .select()
        .eq('pet_id', petId)
        .gte('recorded_date', _formatDate(start))
        .lte('recorded_date', _formatDate(end))
        .order('recorded_date', ascending: true);

    return (response as List)
        .map((json) => WeightRecord.fromJson(json))
        .toList();
  }

  /// 월별 체중 평균 조회 (DB 함수 호출)
  Future<List<Map<String, dynamic>>> getMonthlyAverages(
    String petId, {
    int? year,
  }) async {
    final response = await _client.rpc(
      'get_monthly_weight_averages',
      params: {
        'p_pet_id': petId,
        if (year != null) 'p_year': year,
      },
    );

    return List<Map<String, dynamic>>.from(response as List);
  }

  /// 주간 체중 데이터 조회 (DB 함수 호출)
  Future<List<Map<String, dynamic>>> getWeeklyData(
    String petId,
    int year,
    int month,
    int week,
  ) async {
    final response = await _client.rpc(
      'get_weekly_weight_data',
      params: {
        'p_pet_id': petId,
        'p_year': year,
        'p_month': month,
        'p_week': week,
      },
    );

    return List<Map<String, dynamic>>.from(response as List);
  }

  /// 날짜 포맷 (YYYY-MM-DD)
  String _formatDate(DateTime date) {
    return date.toIso8601String().split('T').first;
  }
}
