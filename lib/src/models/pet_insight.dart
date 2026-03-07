/// 주간/월간 건강 인사이트 모델
class PetInsight {
  final String id;
  final String petId;
  final String insightType; // "weekly" / "monthly"
  final DateTime periodStart;
  final DateTime periodEnd;
  final String summary;
  final Map<String, dynamic> keyMetrics;
  final List<String> recommendations;
  final String language;
  final DateTime generatedAt;

  const PetInsight({
    required this.id,
    required this.petId,
    required this.insightType,
    required this.periodStart,
    required this.periodEnd,
    required this.summary,
    required this.keyMetrics,
    required this.recommendations,
    required this.language,
    required this.generatedAt,
  });

  factory PetInsight.fromJson(Map<String, dynamic> json) {
    return PetInsight(
      id: json['id'] as String,
      petId: json['pet_id'] as String,
      insightType: json['insight_type'] as String? ?? 'weekly',
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      summary: json['summary'] as String? ?? '',
      keyMetrics: json['key_metrics'] as Map<String, dynamic>? ?? {},
      recommendations: (json['recommendations'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      language: json['language'] as String? ?? 'zh',
      generatedAt: DateTime.parse(json['generated_at'] as String),
    );
  }
}
