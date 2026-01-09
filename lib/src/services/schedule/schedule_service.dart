import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/schedule_record.dart';

/// 일정 관리 서비스
/// Supabase schedules 테이블과 연동
class ScheduleService {
  final _supabase = Supabase.instance.client;
  static const _tableName = 'schedules';

  /// 일정 생성
  Future<ScheduleRecord> createSchedule(ScheduleRecord schedule) async {
    final response = await _supabase
        .from(_tableName)
        .insert(schedule.toInsertJson())
        .select()
        .single();

    return ScheduleRecord.fromJson(response);
  }

  /// 특정 펫의 모든 일정 조회
  Future<List<ScheduleRecord>> fetchSchedules({
    required String petId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = _supabase
        .from(_tableName)
        .select()
        .eq('pet_id', petId);

    if (startDate != null) {
      query = query.gte('start_time', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('start_time', endDate.toIso8601String());
    }

    final response = await query.order('start_time', ascending: true);

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
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

    return fetchSchedules(
      petId: petId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// 오늘 일정 조회
  Future<List<ScheduleRecord>> fetchTodaySchedules({String? petId}) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    var query = _supabase
        .from(_tableName)
        .select()
        .gte('start_time', startOfDay.toIso8601String())
        .lte('start_time', endOfDay.toIso8601String());

    if (petId != null) {
      query = query.eq('pet_id', petId);
    }

    final response = await query.order('start_time', ascending: true);

    return (response as List)
        .map((json) => ScheduleRecord.fromJson(json))
        .toList();
  }

  /// 특정 날짜의 일정 조회
  Future<List<ScheduleRecord>> fetchSchedulesByDate({
    required String petId,
    required DateTime date,
  }) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final response = await _supabase
        .from(_tableName)
        .select()
        .eq('pet_id', petId)
        .gte('start_time', startOfDay.toIso8601String())
        .lte('start_time', endOfDay.toIso8601String())
        .order('start_time', ascending: true);

    return (response as List)
        .map((json) => ScheduleRecord.fromJson(json))
        .toList();
  }

  /// 일정 수정
  Future<ScheduleRecord> updateSchedule(ScheduleRecord schedule) async {
    final response = await _supabase
        .from(_tableName)
        .update(schedule.toInsertJson())
        .eq('id', schedule.id)
        .select()
        .single();

    return ScheduleRecord.fromJson(response);
  }

  /// 일정 삭제
  Future<void> deleteSchedule(String id) async {
    await _supabase.from(_tableName).delete().eq('id', id);
  }

  /// 여러 일정 삭제 (펫 삭제 시 사용)
  Future<void> deleteSchedulesByPetId(String petId) async {
    await _supabase.from(_tableName).delete().eq('pet_id', petId);
  }
}
