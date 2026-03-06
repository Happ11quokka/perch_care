/// 음식 기록 모델
class FoodRecord {
  final String id;
  final String petId;
  final DateTime recordedDate;
  final double totalGrams;
  final double targetGrams;
  final int count;
  final String? entriesJson;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FoodRecord({
    required this.id,
    required this.petId,
    required this.recordedDate,
    required this.totalGrams,
    required this.targetGrams,
    required this.count,
    this.entriesJson,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FoodRecord.fromJson(Map<String, dynamic> json) {
    return FoodRecord(
      id: json['id'] as String,
      petId: json['pet_id'] as String,
      recordedDate: DateTime.parse(json['recorded_date'] as String),
      totalGrams: (json['total_grams'] as num).toDouble(),
      targetGrams: (json['target_grams'] as num).toDouble(),
      count: json['count'] as int,
      entriesJson: json['entries_json'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'recorded_date': recordedDate.toIso8601String().split('T').first,
      'total_grams': totalGrams,
      'target_grams': targetGrams,
      'count': count,
      if (entriesJson != null) 'entries_json': entriesJson,
    };
  }

  FoodRecord copyWith({
    String? id,
    String? petId,
    DateTime? recordedDate,
    double? totalGrams,
    double? targetGrams,
    int? count,
    String? entriesJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FoodRecord(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      recordedDate: recordedDate ?? this.recordedDate,
      totalGrams: totalGrams ?? this.totalGrams,
      targetGrams: targetGrams ?? this.targetGrams,
      count: count ?? this.count,
      entriesJson: entriesJson ?? this.entriesJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodRecord && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
