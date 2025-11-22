import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/daily_record.dart';

/// 일일 건강 기록 서비스 (캘린더용)
class DailyRecordService {
  DailyRecordService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// 특정 펫의 모든 일일 기록 조회
  Future<List<DailyRecord>> getDailyRecords(String petId) async {
    final response = await _client
        .from('daily_records')
        .select()
        .eq('pet_id', petId)
        .order('recorded_date', ascending: false);

    return (response as List)
        .map((json) => DailyRecord.fromJson(json))
        .toList();
  }

  /// 특정 날짜의 일일 기록 조회
  Future<DailyRecord?> getRecordByDate(String petId, DateTime date) async {
    final dateStr = _formatDate(date);

    final response = await _client
        .from('daily_records')
        .select()
        .eq('pet_id', petId)
        .eq('recorded_date', dateStr)
        .maybeSingle();

    return response != null ? DailyRecord.fromJson(response) : null;
  }

  /// 특정 월의 일일 기록 조회 (캘린더용)
  Future<List<DailyRecord>> getRecordsByMonth(
    String petId,
    int year,
    int month,
  ) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0); // 해당 월의 마지막 날

    final response = await _client
        .from('daily_records')
        .select()
        .eq('pet_id', petId)
        .gte('recorded_date', _formatDate(startDate))
        .lte('recorded_date', _formatDate(endDate))
        .order('recorded_date', ascending: true);

    return (response as List)
        .map((json) => DailyRecord.fromJson(json))
        .toList();
  }

  /// 일일 기록 저장 또는 수정 (Upsert)
  Future<DailyRecord> saveDailyRecord(DailyRecord record) async {
    final response = await _client
        .from('daily_records')
        .upsert(
          record.toInsertJson(),
          onConflict: 'pet_id,recorded_date',
        )
        .select()
        .single();

    return DailyRecord.fromJson(response);
  }

  /// 일일 기록 삭제
  Future<void> deleteDailyRecord(String recordId) async {
    await _client.from('daily_records').delete().eq('id', recordId);
  }

  /// 특정 날짜의 일일 기록 삭제
  Future<void> deleteDailyRecordByDate(String petId, DateTime date) async {
    final dateStr = _formatDate(date);
    await _client
        .from('daily_records')
        .delete()
        .eq('pet_id', petId)
        .eq('recorded_date', dateStr);
  }

  /// 특정 기간의 일일 기록 조회
  Future<List<DailyRecord>> getRecordsByDateRange(
    String petId,
    DateTime start,
    DateTime end,
  ) async {
    final response = await _client
        .from('daily_records')
        .select()
        .eq('pet_id', petId)
        .gte('recorded_date', _formatDate(start))
        .lte('recorded_date', _formatDate(end))
        .order('recorded_date', ascending: true);

    return (response as List)
        .map((json) => DailyRecord.fromJson(json))
        .toList();
  }

  /// 날짜 포맷 (YYYY-MM-DD)
  String _formatDate(DateTime date) {
    return date.toIso8601String().split('T').first;
  }
}
