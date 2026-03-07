/// 건강 변화 요약 모델
class HealthSummary {
  final double? bhiScore;
  final int wciLevel;
  final double? weightCurrent;
  final double? weightChangePercent;
  final String weightTrend; // "up" / "down" / "stable"
  final bool hasData;
  final DateTime targetDate;

  // Premium 전용
  final int? abnormalCount;
  final double? foodConsistency;
  final double? waterConsistency;
  final String? bhiTrend; // "improving" / "declining" / "stable"
  final double? bhiPrevious;

  const HealthSummary({
    this.bhiScore,
    required this.wciLevel,
    this.weightCurrent,
    this.weightChangePercent,
    required this.weightTrend,
    required this.hasData,
    required this.targetDate,
    this.abnormalCount,
    this.foodConsistency,
    this.waterConsistency,
    this.bhiTrend,
    this.bhiPrevious,
  });

  factory HealthSummary.fromJson(Map<String, dynamic> json) {
    return HealthSummary(
      bhiScore: (json['bhi_score'] as num?)?.toDouble(),
      wciLevel: json['wci_level'] as int? ?? 0,
      weightCurrent: (json['weight_current'] as num?)?.toDouble(),
      weightChangePercent: (json['weight_change_percent'] as num?)?.toDouble(),
      weightTrend: json['weight_trend'] as String? ?? 'stable',
      hasData: json['has_data'] as bool? ?? false,
      targetDate: DateTime.parse(json['target_date'] as String),
      abnormalCount: json['abnormal_count'] as int?,
      foodConsistency: (json['food_consistency'] as num?)?.toDouble(),
      waterConsistency: (json['water_consistency'] as num?)?.toDouble(),
      bhiTrend: json['bhi_trend'] as String?,
      bhiPrevious: (json['bhi_previous'] as num?)?.toDouble(),
    );
  }
}
