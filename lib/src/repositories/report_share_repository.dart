import '../services/api/api_client.dart';

/// 리포트 공유 링크 발급 Repository.
///
/// 건강 리포트/수의사 요약 공유는 로컬 캐시가 없으므로 `ApiClient` 호출을
/// 얇게 감싸는 것만으로 충분하다. Screen이 `ApiClient.instance`를 직접 호출하던
/// 코드를 제거하기 위한 레이어.
abstract class ReportShareRepository {
  /// 건강 리포트 공유 링크 발급. [from]/[to]는 조회 기간(YYYY-MM-DD로 변환되어 전송).
  Future<String> shareHealthReport({
    required String petId,
    required DateTime from,
    required DateTime to,
  });

  /// 수의사 방문 요약 공유 링크 발급.
  Future<String> shareVetSummary({required String petId});
}

class ReportShareRepositoryImpl implements ReportShareRepository {
  ReportShareRepositoryImpl({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  @override
  Future<String> shareHealthReport({
    required String petId,
    required DateTime from,
    required DateTime to,
  }) async {
    final result = await _api.post(
      '/reports/share/health/$petId?date_from=${_fmt(from)}&date_to=${_fmt(to)}',
    );
    return result['share_url'] as String;
  }

  @override
  Future<String> shareVetSummary({required String petId}) async {
    final result = await _api.post('/reports/share/vet-summary/$petId');
    return result['share_url'] as String;
  }

  /// `YYYY-MM-DD` — history 화면의 기존 포맷과 동일.
  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
