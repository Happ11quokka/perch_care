import 'package:flutter/foundation.dart';
import '../api/api_client.dart';

/// 프리미엄 구독 상태 모델
class PremiumStatus {
  final String tier;
  final DateTime? premiumExpiresAt;

  PremiumStatus({required this.tier, this.premiumExpiresAt});

  bool get isPremium => tier == 'premium';
  bool get isFree => tier != 'premium';

  factory PremiumStatus.fromJson(Map<String, dynamic> json) {
    return PremiumStatus(
      tier: json['tier'] as String? ?? 'free',
      premiumExpiresAt: json['premium_expires_at'] != null
          ? DateTime.parse(json['premium_expires_at'] as String)
          : null,
    );
  }
}

/// 프리미엄 코드 활성화 결과 모델
class PremiumActivationResult {
  final bool success;
  final DateTime? expiresAt;

  PremiumActivationResult({required this.success, this.expiresAt});

  factory PremiumActivationResult.fromJson(Map<String, dynamic> json) {
    return PremiumActivationResult(
      success: json['success'] as bool? ?? false,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
    );
  }
}

/// 프리미엄 서비스 — 티어 조회 + 코드 활성화 (인메모리 캐시 포함)
class PremiumService {
  PremiumService._();
  static final instance = PremiumService._();

  final _api = ApiClient.instance;

  PremiumStatus? _cachedStatus;
  DateTime? _lastFetch;
  static const _cacheDuration = Duration(minutes: 5);

  bool _isCacheValid() =>
      _lastFetch != null &&
      DateTime.now().difference(_lastFetch!) < _cacheDuration;

  void invalidateCache() {
    _cachedStatus = null;
    _lastFetch = null;
  }

  /// 프리미엄 티어 조회 (GET /premium/tier)
  Future<PremiumStatus> getTier({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid() && _cachedStatus != null) {
      debugPrint('[PremiumService] getTier() -> cache hit');
      return _cachedStatus!;
    }

    try {
      final response = await _api.get('/premium/tier');
      final status = PremiumStatus.fromJson(response as Map<String, dynamic>);
      _cachedStatus = status;
      _lastFetch = DateTime.now();
      debugPrint('[PremiumService] getTier() -> server (${status.tier})');
      return status;
    } catch (e) {
      if (_cachedStatus != null) {
        debugPrint('[PremiumService] getTier() -> stale cache fallback');
        return _cachedStatus!;
      }
      rethrow;
    }
  }

  /// 프리미엄 코드 활성화 (POST /premium/activate)
  Future<PremiumActivationResult> activateCode(String code) async {
    final response = await _api.post(
      '/premium/activate',
      body: {'code': code},
    );
    final result =
        PremiumActivationResult.fromJson(response as Map<String, dynamic>);

    if (result.success) {
      invalidateCache();
    }

    return result;
  }
}
