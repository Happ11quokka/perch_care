import 'package:flutter/foundation.dart';
import '../api/api_client.dart';

/// AI 백과사전 쿼터 정보
class EncyclopediaQuota {
  final int monthlyLimit; // -1 = 무제한
  final int monthlyUsed;
  final int remaining; // -1 = 무제한

  EncyclopediaQuota({
    required this.monthlyLimit,
    required this.monthlyUsed,
    required this.remaining,
  });

  bool get isUnlimited => monthlyLimit == -1;
  bool get isExhausted => !isUnlimited && remaining <= 0;
  bool get isWarning => !isUnlimited && remaining <= 3;

  factory EncyclopediaQuota.fromJson(Map<String, dynamic> json) {
    final limit = json['monthly_limit'] as int? ?? 0;
    return EncyclopediaQuota(
      monthlyLimit: limit,
      monthlyUsed: json['monthly_used'] as int? ?? 0,
      remaining: json['remaining'] as int? ?? (limit == -1 ? -1 : 0),
    );
  }
}

/// AI 비전 체크 쿼터 정보
class VisionQuota {
  final int monthlyLimit; // -1 = 무제한
  final int monthlyUsed;
  final int remaining; // -1 = 무제한

  VisionQuota({
    required this.monthlyLimit,
    required this.monthlyUsed,
    required this.remaining,
  });

  bool get isUnlimited => monthlyLimit == -1;
  bool get isExhausted => !isUnlimited && remaining <= 0;
  bool get isWarning => !isUnlimited && remaining <= 3;

  factory VisionQuota.fromJson(Map<String, dynamic> json) {
    final limit = json['monthly_limit'] as int? ?? 0;
    return VisionQuota(
      monthlyLimit: limit,
      monthlyUsed: json['monthly_used'] as int? ?? 0,
      remaining: json['remaining'] as int? ?? (limit == -1 ? -1 : 0),
    );
  }
}

/// AI 기능 쿼터 통합 정보
class QuotaInfo {
  final EncyclopediaQuota aiEncyclopedia;
  final VisionQuota vision;

  QuotaInfo({
    required this.aiEncyclopedia,
    required this.vision,
  });

  bool get hasVisionAccess => vision.isUnlimited || vision.remaining > 0;

  factory QuotaInfo.fromJson(Map<String, dynamic> json) {
    return QuotaInfo(
      aiEncyclopedia: EncyclopediaQuota.fromJson(
        json['ai_encyclopedia'] as Map<String, dynamic>,
      ),
      vision: VisionQuota.fromJson(
        json['vision'] as Map<String, dynamic>,
      ),
    );
  }
}

/// 프리미엄 구독 상태 모델
class PremiumStatus {
  final String tier;
  final DateTime? premiumExpiresAt;
  final String? source;
  final String? storeProductId;
  final bool? autoRenewStatus;
  final QuotaInfo? quota;

  PremiumStatus({
    required this.tier,
    this.premiumExpiresAt,
    this.source,
    this.storeProductId,
    this.autoRenewStatus,
    this.quota,
  });

  bool get isPremium => tier == 'premium';
  bool get isFree => tier != 'premium';
  bool get isStoreSubscription =>
      source == 'app_store' || source == 'play_store';

  factory PremiumStatus.fromJson(Map<String, dynamic> json) {
    return PremiumStatus(
      tier: json['tier'] as String? ?? 'free',
      premiumExpiresAt: json['premium_expires_at'] != null
          ? DateTime.parse(json['premium_expires_at'] as String)
          : null,
      source: json['source'] as String?,
      storeProductId: json['store_product_id'] as String?,
      autoRenewStatus: json['auto_renew_status'] as bool?,
      quota: json['quota'] != null
          ? QuotaInfo.fromJson(json['quota'] as Map<String, dynamic>)
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
