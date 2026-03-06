/// 품종별 체중 표준 모델
class BreedStandard {
  final String id;
  final String displayName;
  final String speciesCategory;
  final String? breedVariant;
  final double weightMinG;
  final double weightIdealMinG;
  final double weightIdealMaxG;
  final double weightMaxG;

  const BreedStandard({
    required this.id,
    required this.displayName,
    required this.speciesCategory,
    this.breedVariant,
    required this.weightMinG,
    required this.weightIdealMinG,
    required this.weightIdealMaxG,
    required this.weightMaxG,
  });

  factory BreedStandard.fromJson(Map<String, dynamic> json) {
    return BreedStandard(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      speciesCategory: json['species_category'] as String,
      breedVariant: json['breed_variant'] as String?,
      weightMinG: (json['weight_min_g'] as num).toDouble(),
      weightIdealMinG: (json['weight_ideal_min_g'] as num).toDouble(),
      weightIdealMaxG: (json['weight_ideal_max_g'] as num).toDouble(),
      weightMaxG: (json['weight_max_g'] as num).toDouble(),
    );
  }

  /// 이상적 체중 범위 텍스트
  String get idealRangeText =>
      '${weightIdealMinG.toStringAsFixed(0)}g - ${weightIdealMaxG.toStringAsFixed(0)}g';

  /// 전체 범위 텍스트
  String get fullRangeText =>
      '${weightMinG.toStringAsFixed(0)}g - ${weightMaxG.toStringAsFixed(0)}g';
}

/// BHI 응답에 포함되는 체중 범위 위치 정보
class WeightRangeInfo {
  final double minG;
  final double idealMinG;
  final double idealMaxG;
  final double maxG;
  final String currentPosition; // "below_min", "below_ideal", "in_ideal", "above_ideal", "above_max"
  final double currentPercentage; // 0-100

  const WeightRangeInfo({
    required this.minG,
    required this.idealMinG,
    required this.idealMaxG,
    required this.maxG,
    required this.currentPosition,
    required this.currentPercentage,
  });

  factory WeightRangeInfo.fromJson(Map<String, dynamic> json) {
    return WeightRangeInfo(
      minG: (json['min_g'] as num).toDouble(),
      idealMinG: (json['ideal_min_g'] as num).toDouble(),
      idealMaxG: (json['ideal_max_g'] as num).toDouble(),
      maxG: (json['max_g'] as num).toDouble(),
      currentPosition: json['current_position'] as String,
      currentPercentage: (json['current_percentage'] as num).toDouble(),
    );
  }
}
