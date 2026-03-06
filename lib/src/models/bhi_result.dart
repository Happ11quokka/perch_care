/// BHI (Bird Health Index) 결과 모델
class BhiResult {
  final double bhiScore;
  final double weightScore;
  final double foodScore;
  final double waterScore;
  final int wciLevel;
  final String? growthStage;
  final DateTime targetDate;
  final bool hasWeightData;
  final bool hasFoodData;
  final bool hasWaterData;
  // Debug fields
  final double? debugFoodTotal;
  final double? debugFoodTarget;
  final double? debugWaterTotal;
  final double? debugWaterTarget;

  const BhiResult({
    required this.bhiScore,
    required this.weightScore,
    required this.foodScore,
    required this.waterScore,
    required this.wciLevel,
    this.growthStage,
    required this.targetDate,
    required this.hasWeightData,
    required this.hasFoodData,
    required this.hasWaterData,
    this.debugFoodTotal,
    this.debugFoodTarget,
    this.debugWaterTotal,
    this.debugWaterTarget,
  });

  factory BhiResult.fromJson(Map<String, dynamic> json) {
    return BhiResult(
      bhiScore: (json['bhi_score'] as num).toDouble(),
      weightScore: (json['weight_score'] as num).toDouble(),
      foodScore: (json['food_score'] as num).toDouble(),
      waterScore: (json['water_score'] as num).toDouble(),
      wciLevel: json['wci_level'] as int,
      growthStage: json['growth_stage'] as String?,
      targetDate: DateTime.parse(json['target_date'] as String),
      hasWeightData: json['has_weight_data'] as bool,
      hasFoodData: json['has_food_data'] as bool,
      hasWaterData: json['has_water_data'] as bool,
      debugFoodTotal: (json['debug_food_total'] as num?)?.toDouble(),
      debugFoodTarget: (json['debug_food_target'] as num?)?.toDouble(),
      debugWaterTotal: (json['debug_water_total'] as num?)?.toDouble(),
      debugWaterTarget: (json['debug_water_target'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bhi_score': bhiScore,
      'weight_score': weightScore,
      'food_score': foodScore,
      'water_score': waterScore,
      'wci_level': wciLevel,
      if (growthStage != null) 'growth_stage': growthStage,
      'target_date': targetDate.toIso8601String().split('T').first,
      'has_weight_data': hasWeightData,
      'has_food_data': hasFoodData,
      'has_water_data': hasWaterData,
    };
  }
}
