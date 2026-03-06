/// 수분 섭취 기록 모델
class WaterIntakeRecord {
  final String id;
  final String petId;
  final DateTime recordedDate;
  final double totalMl;
  final double targetMl;
  final int count;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WaterIntakeRecord({
    required this.id,
    required this.petId,
    required this.recordedDate,
    required this.totalMl,
    required this.targetMl,
    required this.count,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WaterIntakeRecord.fromJson(Map<String, dynamic> json) {
    return WaterIntakeRecord(
      id: json['id'] as String,
      petId: json['pet_id'] as String,
      recordedDate: DateTime.parse(json['recorded_date'] as String),
      totalMl: (json['total_ml'] as num).toDouble(),
      targetMl: (json['target_ml'] as num).toDouble(),
      count: json['count'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'recorded_date': recordedDate.toIso8601String().split('T').first,
      'total_ml': totalMl,
      'target_ml': targetMl,
      'count': count,
    };
  }

  WaterIntakeRecord copyWith({
    String? id,
    String? petId,
    DateTime? recordedDate,
    double? totalMl,
    double? targetMl,
    int? count,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WaterIntakeRecord(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      recordedDate: recordedDate ?? this.recordedDate,
      totalMl: totalMl ?? this.totalMl,
      targetMl: targetMl ?? this.targetMl,
      count: count ?? this.count,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaterIntakeRecord &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
