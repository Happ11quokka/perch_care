import 'package:flutter/foundation.dart';
import '../../models/breed_standard.dart';
import '../api/api_client.dart';

/// 품종 표준 데이터 서비스 (세션 내 캐시)
class BreedService {
  BreedService._();
  static final instance = BreedService._();

  final _api = ApiClient.instance;

  // 세션 내 캐시 (품종 데이터는 변경 빈도 낮음)
  List<BreedStandard>? _cachedBreeds;

  /// 전체 품종 목록 조회 (캐시-우선)
  Future<List<BreedStandard>> fetchBreedStandards({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedBreeds != null) {
      return _cachedBreeds!;
    }

    try {
      final response = await _api.get('/breed-standards/');
      final breeds = (response as List)
          .map((json) => BreedStandard.fromJson(json))
          .toList();
      _cachedBreeds = breeds;
      debugPrint('[BreedService] fetchBreedStandards() → ${breeds.length} breeds');
      return breeds;
    } catch (e) {
      debugPrint('[BreedService] fetchBreedStandards() failed: $e');
      return _cachedBreeds ?? [];
    }
  }

  /// ID로 품종 조회
  Future<BreedStandard?> fetchBreedById(String breedId) async {
    // 캐시에서 먼저 검색
    if (_cachedBreeds != null) {
      try {
        return _cachedBreeds!.firstWhere((b) => b.id == breedId);
      } catch (_) {
        // not found in cache
      }
    }

    try {
      final response = await _api.get('/breed-standards/$breedId');
      return BreedStandard.fromJson(response);
    } catch (e) {
      debugPrint('[BreedService] fetchBreedById($breedId) failed: $e');
      return null;
    }
  }

  /// 캐시 무효화
  void invalidateCache() {
    _cachedBreeds = null;
  }
}
