import '../../models/bhi_result.dart';
import '../api/api_client.dart';

/// BHI (Bird Health Index) 조회 서비스 — (petId, 날짜) 단위 인메모리 캐시.
///
/// 홈 화면의 모든 호출 경로(초기 로드/기간 탭/기록 복귀 refreshBhi)가
/// targetDate를 명시하므로, 캐시 키에 날짜를 포함해야 캐시가 실제로 동작한다.
/// 기록 저장/삭제 시 Repository가 `invalidateCache()`를 호출해 신선도를 보장한다.
class BhiService {
  BhiService._();
  static final instance = BhiService._();

  final _api = ApiClient.instance;

  // 'petId|yyyy-MM-dd' → 조회 결과. 월/주 탭 연타·화면 복귀의 중복 왕복 제거용.
  final Map<String, ({BhiResult result, DateTime fetchedAt})> _cache = {};
  static const _cacheDuration = Duration(minutes: 5);
  static const _maxCacheEntries = 32;

  // UI 표시용 서버 조회 시점 (캐시 제어와 분리)
  DateTime? _lastServerFetchTime;

  /// 마지막 서버 조회 성공 시점 (UI 타임스탬프용)
  DateTime? get lastServerFetchTime => _lastServerFetchTime;

  String _dateKey(DateTime date) => date.toIso8601String().split('T').first;

  String _cacheKey(String petId, DateTime date) => '$petId|${_dateKey(date)}';

  /// 캐시 무효화 — 체중/사료/수분 등 BHI 입력 데이터 변경 후 호출.
  /// (`_lastServerFetchTime`은 '마지막으로 서버에서 받아온 시점' UI 표기이므로 유지)
  void invalidateCache() {
    _cache.clear();
  }

  /// 특정 날짜의 BHI 점수 조회 (캐시-우선)
  Future<BhiResult> getBhi(String petId,
      {DateTime? targetDate, bool forceRefresh = false}) async {
    final resolvedDate = targetDate ?? DateTime.now();
    final key = _cacheKey(petId, resolvedDate);
    final cached = _cache[key];

    // 1순위: (펫, 날짜) 인메모리 캐시
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheDuration) {
      return cached.result;
    }

    // targetDate 미지정 호출은 기존과 동일하게 파라미터 없이 서버 기본값 사용
    final queryString =
        targetDate != null ? '?target_date=${_dateKey(targetDate)}' : '';

    try {
      // 2순위: 서버 API
      final response = await _api.get('/pets/$petId/bhi/$queryString');
      final result = BhiResult.fromJson(response);
      _lastServerFetchTime = DateTime.now();

      if (_cache.length >= _maxCacheEntries) {
        _cache.remove(_cache.keys.first); // 가장 오래된 항목부터 제거
      }
      _cache[key] = (result: result, fetchedAt: DateTime.now());
      return result;
    } catch (e) {
      // 3순위: 만료된 동일 (펫, 날짜) 캐시 폴백 (일시적 네트워크 실패 등)
      if (cached != null) {
        return cached.result;
      }
      rethrow;
    }
  }
}
