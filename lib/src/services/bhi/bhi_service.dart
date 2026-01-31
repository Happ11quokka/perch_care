import '../../models/bhi_result.dart';
import '../api/api_client.dart';

/// BHI (Bird Health Index) 조회 서비스
class BhiService {
  BhiService._();
  static final instance = BhiService._();

  final _api = ApiClient.instance;

  /// 특정 날짜의 BHI 점수 조회
  Future<BhiResult> getBhi(String petId, {DateTime? targetDate}) async {
    final params = <String, String>{};
    if (targetDate != null) {
      params['target_date'] = targetDate.toIso8601String().split('T').first;
    }

    final queryString = params.isNotEmpty
        ? '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}'
        : '';

    final response = await _api.get('/pets/$petId/bhi/$queryString');
    return BhiResult.fromJson(response);
  }
}
