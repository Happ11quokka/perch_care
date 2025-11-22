import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/ai_health_check.dart';

/// AI 건강 체크 서비스
class HealthCheckService {
  HealthCheckService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  /// 특정 펫의 모든 건강 체크 기록 조회
  Future<List<AiHealthCheck>> getHealthChecks(String petId) async {
    final response = await _client
        .from('ai_health_checks')
        .select()
        .eq('pet_id', petId)
        .order('checked_at', ascending: false);

    return (response as List)
        .map((json) => AiHealthCheck.fromJson(json))
        .toList();
  }

  /// 특정 펫의 최근 건강 체크 기록 조회
  Future<List<AiHealthCheck>> getRecentHealthChecks(
    String petId, {
    int limit = 10,
  }) async {
    final response = await _client
        .from('ai_health_checks')
        .select()
        .eq('pet_id', petId)
        .order('checked_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => AiHealthCheck.fromJson(json))
        .toList();
  }

  /// 특정 타입의 건강 체크 기록 조회
  Future<List<AiHealthCheck>> getHealthChecksByType(
    String petId,
    String checkType,
  ) async {
    final response = await _client
        .from('ai_health_checks')
        .select()
        .eq('pet_id', petId)
        .eq('check_type', checkType)
        .order('checked_at', ascending: false);

    return (response as List)
        .map((json) => AiHealthCheck.fromJson(json))
        .toList();
  }

  /// 특정 건강 체크 기록 조회
  Future<AiHealthCheck?> getHealthCheckById(String checkId) async {
    final response = await _client
        .from('ai_health_checks')
        .select()
        .eq('id', checkId)
        .maybeSingle();

    return response != null ? AiHealthCheck.fromJson(response) : null;
  }

  /// 건강 체크 기록 저장
  Future<AiHealthCheck> saveHealthCheck(AiHealthCheck check) async {
    final response = await _client
        .from('ai_health_checks')
        .insert(check.toInsertJson())
        .select()
        .single();

    return AiHealthCheck.fromJson(response);
  }

  /// 건강 체크 기록 삭제
  Future<void> deleteHealthCheck(String checkId) async {
    await _client.from('ai_health_checks').delete().eq('id', checkId);
  }

  /// 이미지 업로드 (health-check-images 버킷)
  Future<String> uploadHealthCheckImage(
    Uint8List imageBytes,
    String fileName,
  ) async {
    if (_userId == null) throw Exception('User not logged in');

    final path = '$_userId/$fileName';

    await _client.storage
        .from('health-check-images')
        .uploadBinary(path, imageBytes);

    return _client.storage.from('health-check-images').getPublicUrl(path);
  }

  /// 특정 기간의 건강 체크 기록 조회
  Future<List<AiHealthCheck>> getHealthChecksByDateRange(
    String petId,
    DateTime start,
    DateTime end,
  ) async {
    final response = await _client
        .from('ai_health_checks')
        .select()
        .eq('pet_id', petId)
        .gte('checked_at', start.toIso8601String())
        .lte('checked_at', end.toIso8601String())
        .order('checked_at', ascending: false);

    return (response as List)
        .map((json) => AiHealthCheck.fromJson(json))
        .toList();
  }

  /// 상태별 건강 체크 기록 조회
  Future<List<AiHealthCheck>> getHealthChecksByStatus(
    String petId,
    String status,
  ) async {
    final response = await _client
        .from('ai_health_checks')
        .select()
        .eq('pet_id', petId)
        .eq('status', status)
        .order('checked_at', ascending: false);

    return (response as List)
        .map((json) => AiHealthCheck.fromJson(json))
        .toList();
  }

  /// 경고/위험 상태의 최근 체크 기록 조회
  Future<List<AiHealthCheck>> getAbnormalHealthChecks(
    String petId, {
    int limit = 5,
  }) async {
    final response = await _client
        .from('ai_health_checks')
        .select()
        .eq('pet_id', petId)
        .neq('status', 'normal')
        .order('checked_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => AiHealthCheck.fromJson(json))
        .toList();
  }
}
