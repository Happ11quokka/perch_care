import 'dart:typed_data';
import '../../models/ai_health_check.dart';
import '../api/api_client.dart';

/// AI 건강 체크 서비스
class HealthCheckService {
  HealthCheckService();

  final _api = ApiClient.instance;

  /// 특정 펫의 모든 건강 체크 기록 조회
  Future<List<AiHealthCheck>> getHealthChecks(String petId) async {
    final response = await _api.get('/pets/$petId/health-checks/');
    return (response as List)
        .map((json) => AiHealthCheck.fromJson(json))
        .toList();
  }

  /// 특정 펫의 최근 건강 체크 기록 조회
  Future<List<AiHealthCheck>> getRecentHealthChecks(
    String petId, {
    int limit = 10,
  }) async {
    final response = await _api.get(
      '/pets/$petId/health-checks/recent',
      queryParams: {'limit': limit.toString()},
    );
    return (response as List)
        .map((json) => AiHealthCheck.fromJson(json))
        .toList();
  }

  /// 특정 타입의 건강 체크 기록 조회
  Future<List<AiHealthCheck>> getHealthChecksByType(
    String petId,
    String checkType,
  ) async {
    final response = await _api.get('/pets/$petId/health-checks/by-type/$checkType');
    return (response as List)
        .map((json) => AiHealthCheck.fromJson(json))
        .toList();
  }

  /// 특정 건강 체크 기록 조회
  Future<AiHealthCheck?> getHealthCheckById(String checkId, {required String petId}) async {
    try {
      final response = await _api.get('/pets/$petId/health-checks/$checkId');
      return AiHealthCheck.fromJson(response);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// 건강 체크 기록 저장
  Future<AiHealthCheck> saveHealthCheck(AiHealthCheck check) async {
    final response = await _api.post(
      '/pets/${check.petId}/health-checks/',
      body: check.toInsertJson(),
    );
    return AiHealthCheck.fromJson(response);
  }

  /// 건강 체크 기록 삭제
  Future<void> deleteHealthCheck(String checkId, {required String petId}) async {
    await _api.delete('/pets/$petId/health-checks/$checkId');
  }

  /// 이미지 업로드
  Future<String> uploadHealthCheckImage(
    Uint8List imageBytes,
    String fileName, {
    required String petId,
  }) async {
    final response = await _api.uploadFile(
      '/pets/$petId/health-checks/upload-image',
      imageBytes,
      fileName,
    );
    return response['image_url'] as String;
  }

  /// 특정 기간의 건강 체크 기록 조회
  Future<List<AiHealthCheck>> getHealthChecksByDateRange(
    String petId,
    DateTime start,
    DateTime end,
  ) async {
    final response = await _api.get(
      '/pets/$petId/health-checks/range',
      queryParams: {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      },
    );
    return (response as List)
        .map((json) => AiHealthCheck.fromJson(json))
        .toList();
  }

  /// 상태별 건강 체크 기록 조회
  Future<List<AiHealthCheck>> getHealthChecksByStatus(
    String petId,
    String status,
  ) async {
    final response = await _api.get('/pets/$petId/health-checks/by-status/$status');
    return (response as List)
        .map((json) => AiHealthCheck.fromJson(json))
        .toList();
  }

  /// 경고/위험 상태의 최근 체크 기록 조회
  Future<List<AiHealthCheck>> getAbnormalHealthChecks(
    String petId, {
    int limit = 5,
  }) async {
    final response = await _api.get(
      '/pets/$petId/health-checks/abnormal',
      queryParams: {'limit': limit.toString()},
    );
    return (response as List)
        .map((json) => AiHealthCheck.fromJson(json))
        .toList();
  }
}
