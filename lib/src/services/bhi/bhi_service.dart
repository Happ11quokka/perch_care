import 'package:flutter/foundation.dart';

import '../../models/bhi_result.dart';
import '../api/api_client.dart';

/// BHI (Bird Health Index) 조회 서비스 (인메모리 캐시 포함)
class BhiService {
  BhiService._();
  static final instance = BhiService._();

  final _api = ApiClient.instance;

  // 인메모리 캐시
  BhiResult? _cachedBhi;
  String? _cachedPetId;
  DateTime? _lastBhiFetch;
  static const _cacheDuration = Duration(minutes: 5);

  bool _isCacheValid(String petId) =>
      _cachedPetId == petId &&
      _lastBhiFetch != null &&
      DateTime.now().difference(_lastBhiFetch!) < _cacheDuration;

  /// 캐시 무효화 (데이터 변경 후 호출)
  void invalidateCache() {
    _cachedBhi = null;
    _cachedPetId = null;
    _lastBhiFetch = null;
  }

  /// 특정 날짜의 BHI 점수 조회 (캐시-우선)
  Future<BhiResult> getBhi(String petId, {DateTime? targetDate, bool forceRefresh = false}) async {
    // 1순위: 인메모리 캐시 (targetDate 없는 경우만)
    if (!forceRefresh && targetDate == null && _isCacheValid(petId) && _cachedBhi != null) {
      debugPrint('[BhiService] getBhi() → cache hit');
      return _cachedBhi!;
    }

    final params = <String, String>{};
    if (targetDate != null) {
      params['target_date'] = targetDate.toIso8601String().split('T').first;
    }

    final queryString = params.isNotEmpty
        ? '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}'
        : '';

    try {
      // 2순위: 서버 API
      final response = await _api.get('/pets/$petId/bhi/$queryString');
      final result = BhiResult.fromJson(response);

      // targetDate 없는 기본 조회만 캐시
      if (targetDate == null) {
        _cachedBhi = result;
        _cachedPetId = petId;
        _lastBhiFetch = DateTime.now();
      }
      debugPrint('[BhiService] getBhi() → server');
      return result;
    } catch (e) {
      // 3순위: 만료된 인메모리 캐시
      if (_cachedBhi != null && _cachedPetId == petId) {
        debugPrint('[BhiService] getBhi() → stale cache fallback');
        return _cachedBhi!;
      }
      rethrow;
    }
  }
}
